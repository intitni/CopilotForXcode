import AppKit
import AXExtension
import AXNotificationStream
import Combine
import Foundation

public class XcodeWindowInspector: ObservableObject {
    let uiElement: AXUIElement

    init(uiElement: AXUIElement) {
        self.uiElement = uiElement
    }
}

public final class WorkspaceXcodeWindowInspector: XcodeWindowInspector {
    let app: NSRunningApplication
    @Published var documentURL: URL = .init(fileURLWithPath: "/")
    @Published var projectURL: URL = .init(fileURLWithPath: "/")
    private var updateTabsTask: Task<Void, Error>?
    private var focusedElementChangedTask: Task<Void, Error>?

    deinit {
        updateTabsTask?.cancel()
        focusedElementChangedTask?.cancel()
    }

    init(app: NSRunningApplication, uiElement: AXUIElement) {
        self.app = app
        super.init(uiElement: uiElement)

        focusedElementChangedTask = Task { @MainActor in
            let update = {
                let documentURL = Self.extractDocumentURL(app, windowElement: uiElement)
                if let documentURL {
                    self.documentURL = documentURL
                }
                let projectURL = Self.extractProjectURL(
                    app,
                    windowElement: uiElement,
                    fileURL: documentURL
                )
                if let projectURL {
                    self.projectURL = projectURL
                }
            }

            update()
            let notifications = AXNotificationStream(
                app: app,
                element: uiElement,
                notificationNames: kAXFocusedUIElementChangedNotification
            )

            for await _ in notifications {
                try Task.checkCancellation()
                update()
            }
        }
    }

    static func extractDocumentURL(
        _ app: NSRunningApplication,
        windowElement: AXUIElement
    ) -> URL? {
        // fetch file path of the frontmost window of Xcode through Accessability API.
        let application = AXUIElementCreateApplication(app.processIdentifier)
        var path = windowElement.document
        if let path = path?.removingPercentEncoding {
            let url = URL(
                fileURLWithPath: path
                    .replacingOccurrences(of: "file://", with: "")
            )
            return url
        }
        return nil
    }

    static func extractProjectURL(
        _ app: NSRunningApplication,
        windowElement: AXUIElement,
        fileURL: URL?
    ) -> URL? {
        let application = AXUIElementCreateApplication(app.processIdentifier)
        let focusedWindow = application.focusedWindow
        for child in focusedWindow?.children ?? [] {
            if child.description.starts(with: "/"), child.description.count > 1 {
                let path = child.description
                let trimmedNewLine = path.trimmingCharacters(in: .newlines)
                var url = URL(fileURLWithPath: trimmedNewLine)
                while !FileManager.default.fileIsDirectory(atPath: url.path) ||
                    !url.pathExtension.isEmpty
                {
                    url = url.deletingLastPathComponent()
                }
                return url
            }
        }

        guard var currentURL = fileURL else { return nil }
        var firstDirectoryURL: URL?
        while currentURL.pathComponents.count > 1 {
            defer { currentURL.deleteLastPathComponent() }
            guard FileManager.default.fileIsDirectory(atPath: currentURL.path) else { continue }
            if firstDirectoryURL == nil { firstDirectoryURL = currentURL }
            let gitURL = currentURL.appendingPathComponent(".git")
            if FileManager.default.fileIsDirectory(atPath: gitURL.path) {
                return currentURL
            }
        }

        return firstDirectoryURL ?? fileURL
    }
}

