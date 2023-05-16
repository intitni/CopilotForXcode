import AppKit
import AXExtension
import AXNotificationStream
import Combine
import Foundation

public final class XcodeInspector: ObservableObject {
    public static let shared = XcodeInspector()

    private var cancellable = Set<AnyCancellable>()
    private var activeXcodeObservations = Set<Task<Void, Error>>()

    @Published public internal(set) var activeApplication: AppInstanceInspector?
    @Published public internal(set) var activeXcode: XcodeAppInstanceInspector?
    @Published public internal(set) var latestActiveXcode: XcodeAppInstanceInspector?
    @Published public internal(set) var xcodes: [XcodeAppInstanceInspector] = []
    @Published public internal(set) var activeProjectPath = ""
    @Published public internal(set) var activeDocumentPath = ""
    @Published public internal(set) var focusedWindow: XcodeWindowInspector?
    @Published public internal(set) var focusedEditor: SourceEditor?
    @Published public internal(set) var focusedElement: AXUIElement?

    init() {
        let runningApplications = NSWorkspace.shared.runningApplications
        xcodes = runningApplications
            .filter { $0.isXcode }
            .map(XcodeAppInstanceInspector.init(runningApplication:))
        let activeXcode = xcodes.first(where: \.isActive)
        activeApplication = activeXcode ?? runningApplications
            .first(where: \.isActive)
            .map(AppInstanceInspector.init(runningApplication:))

        for xcode in xcodes {
            observeXcode(xcode)
        }

        if let activeXcode {
            setActiveXcode(activeXcode)
        }

        Task { @MainActor in // Did activate app
            let sequence = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didActivateApplicationNotification)
            for await notification in sequence {
                try Task.checkCancellation()
                guard let app = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { continue }
                if app.isXcode {
                    if let existed = xcodes.first(
                        where: { $0.runningApplication.processIdentifier == app.processIdentifier }
                    ) {
                        setActiveXcode(existed)
                    } else {
                        let new = XcodeAppInstanceInspector(runningApplication: app)
                        xcodes.append(new)
                        setActiveXcode(new)
                        observeXcode(new)
                    }
                } else {
                    activeApplication = AppInstanceInspector(runningApplication: app)
                }
            }
        }

        Task { @MainActor in // Did terminate app
            let sequence = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didTerminateApplicationNotification)
            for await notification in sequence {
                try Task.checkCancellation()
                guard let app = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { continue }
                if app.isXcode {
                    xcodes.removeAll {
                        $0.runningApplication.processIdentifier == app.processIdentifier
                    }
                    if latestActiveXcode?.runningApplication.processIdentifier
                        == app.processIdentifier
                    {
                        latestActiveXcode = nil
                    }

                    if let activeXcode = xcodes.first(where: \.isActive) {
                        setActiveXcode(activeXcode)
                    }
                }
            }
        }
    }

    func observeXcode(_ xcode: XcodeAppInstanceInspector) {
        xcode.$document.filter { _ in xcode.isActive }.assign(to: &$activeDocumentPath)
        xcode.$focusedWindow.filter { _ in xcode.isActive }.assign(to: &$focusedWindow)
    }

    func setActiveXcode(_ xcode: XcodeAppInstanceInspector) {
        for task in activeXcodeObservations { task.cancel() }
        activeXcodeObservations.removeAll()

        activeXcode = xcode
        latestActiveXcode = xcode
        activeDocumentPath = xcode.document
        focusedWindow = xcode.focusedWindow

        let focusedElementChanged = Task { @MainActor in
            let notification = AXNotificationStream(
                app: xcode.runningApplication,
                notificationNames: kAXFocusedUIElementChangedNotification
            )
            for await _ in notification {
                try Task.checkCancellation()
                focusedElement = xcode.appElement.focusedElement
                if let editorElement = focusedElement, editorElement.isSourceEditor {
                    focusedEditor = .init(
                        runningApplication: xcode.runningApplication,
                        element: editorElement
                    )
                } else {
                    focusedEditor = nil
                }
            }
        }
    }
}

public class AppInstanceInspector: ObservableObject {
    let runningApplication: NSRunningApplication
    let appElement: AXUIElement
    var isActive: Bool { runningApplication.isActive }

    init(runningApplication: NSRunningApplication) {
        self.runningApplication = runningApplication
        appElement = AXUIElementCreateApplication(runningApplication.processIdentifier)
    }
}

public final class XcodeAppInstanceInspector: AppInstanceInspector {
    @Published var focusedWindow: XcodeWindowInspector?
    var longRunningTasks = Set<Task<Void, Error>>()

    deinit {
        for task in longRunningTasks { task.cancel() }
    }

    override init(runningApplication: NSRunningApplication) {
        super.init(runningApplication: runningApplication)

        let focusedWindowChanged = Task {
            let notification = AXNotificationStream(
                app: runningApplication,
                notificationNames: kAXFocusedWindowChangedNotification
            )
            for await _ in notification {
                try Task.checkCancellation()
                if let window = appElement.focusedWindow {
                    focusedWindow = XcodeWindowInspector(uiElement: window)
                } else {
                    focusedWindow = nil
                }
            }
        }

        longRunningTasks.insert(focusedWindowChanged)
    }
}

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
    @Published var tabs: Set<String> = []
    private var updateTabsTask: Task<Void, Error>?
    private var focusedElementChangedTask: Task<Void, Error>?

    deinit {
        updateTabsTask?.cancel()
        focusedElementChangedTask?.cancel()
    }

    init(app: NSRunningApplication, uiElement: AXUIElement) {
        self.app = app
        super.init(uiElement: uiElement)

        updateTabsTask = Task { @MainActor in
            while true {
                try Task.checkCancellation()
                if let updatedTabs = Self.findAvailableOpenedTabs(app) {
                    tabs = updatedTabs
                }
                try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            }
        }

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

    static func findAvailableOpenedTabs(_ app: NSRunningApplication) -> Set<String>? {
        let app = AXUIElementCreateApplication(app.processIdentifier)
        guard app.isFocused else { return nil }
        let windows = app.windows.filter { $0.identifier == "Xcode.WorkspaceWindow" }
        guard !windows.isEmpty else { return [] }
        var allTabs = Set<String>()
        for window in windows {
            guard let editArea = window.firstChild(where: { $0.description == "editor area" })
            else { continue }
            let tabBars = editArea.children { $0.description == "tab bar" }
            for tabBar in tabBars {
                let tabs = tabBar.children { $0.roleDescription == "tab" }
                for tab in tabs {
                    allTabs.insert(tab.title)
                }
            }
        }
        return allTabs
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

public extension NSRunningApplication {
    var isXcode: Bool { bundleIdentifier == "com.apple.dt.Xcode" }
    var isCopilotForXcodeExtensionService: Bool {
        bundleIdentifier == Bundle.main.bundleIdentifier
    }
}

extension FileManager {
    func fileIsDirectory(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileExists(atPath: path, isDirectory: &isDirectory)
        return isDirectory.boolValue && exists
    }
}

