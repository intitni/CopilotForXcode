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
    
    public func refresh() {
        updateURLs()
    }

    public init(app: NSRunningApplication, uiElement: AXUIElement) {
        self.app = app
        super.init(uiElement: uiElement)

        focusedElementChangedTask = Task { @MainActor in
            updateURLs()
            
            Task { @MainActor in
                // prevent that documentURL may not be available yet
                try await Task.sleep(nanoseconds: 500_000_000)
                if documentURL == .init(fileURLWithPath: "/") {
                    updateURLs()
                }
            }
            
            let notifications = AXNotificationStream(
                app: app,
                notificationNames: kAXFocusedUIElementChangedNotification
            )

            for await _ in notifications {
                try Task.checkCancellation()
                updateURLs()
            }
        }
    }
    
    func updateURLs() {
        let documentURL = Self.extractDocumentURL(windowElement: uiElement)
        if let documentURL {
            self.documentURL = documentURL
        }
        let projectURL = Self.extractProjectURL(
            windowElement: uiElement,
            fileURL: documentURL
        )
        if let projectURL {
            self.projectURL = projectURL
        }
    }

    static func extractDocumentURL(
        windowElement: AXUIElement
    ) -> URL? {
        // fetch file path of the frontmost window of Xcode through Accessibility API.
        let path = windowElement.document
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
        windowElement: AXUIElement,
        fileURL: URL?
    ) -> URL? {
        for child in windowElement.children {
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

