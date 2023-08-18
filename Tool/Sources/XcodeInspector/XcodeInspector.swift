import AppKit
import AsyncAlgorithms
import AXExtension
import AXNotificationStream
import Combine
import Foundation

public final class XcodeInspector: ObservableObject {
    public static let shared = XcodeInspector()

    private var cancellable = Set<AnyCancellable>()
    private var activeXcodeObservations = Set<Task<Void, Error>>()
    private var activeXcodeCancellable = Set<AnyCancellable>()

    @Published public internal(set) var activeApplication: AppInstanceInspector?
    @Published public internal(set) var activeXcode: XcodeAppInstanceInspector?
    @Published public internal(set) var latestActiveXcode: XcodeAppInstanceInspector?
    @Published public internal(set) var xcodes: [XcodeAppInstanceInspector] = []
    @Published public internal(set) var activeProjectURL = URL(fileURLWithPath: "/")
    @Published public internal(set) var activeDocumentURL = URL(fileURLWithPath: "/")
    @Published public internal(set) var focusedWindow: XcodeWindowInspector?
    @Published public internal(set) var focusedEditor: SourceEditor?
    @Published public internal(set) var focusedElement: AXUIElement?
    @Published public internal(set) var completionPanel: AXUIElement?

    public var realtimeActiveDocumentURL: URL {
        latestActiveXcode?.realtimeDocumentURL ?? URL(fileURLWithPath: "/")
    }

    init() {
        let runningApplications = NSWorkspace.shared.runningApplications
        xcodes = runningApplications
            .filter { $0.isXcode }
            .map(XcodeAppInstanceInspector.init(runningApplication:))
        let activeXcode = xcodes.first(where: \.isActive)
        activeApplication = activeXcode ?? runningApplications
            .first(where: \.isActive)
            .map(AppInstanceInspector.init(runningApplication:))

        Task { @MainActor in // Did activate app
            if let activeXcode {
                setActiveXcode(activeXcode)
            }

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

    @MainActor
    func setActiveXcode(_ xcode: XcodeAppInstanceInspector) {
        xcode.refresh()

        for task in activeXcodeObservations { task.cancel() }
        for cancellable in activeXcodeCancellable { cancellable.cancel() }
        activeXcodeObservations.removeAll()
        activeXcodeCancellable.removeAll()

        activeXcode = xcode
        latestActiveXcode = xcode
        activeDocumentURL = xcode.documentURL
        focusedWindow = xcode.focusedWindow
        completionPanel = xcode.completionPanel
        activeProjectURL = xcode.projectURL
        focusedWindow = xcode.focusedWindow

        let setFocusedElement = { [weak self] in
            guard let self else { return }
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

        setFocusedElement()
        let focusedElementChanged = Task { @MainActor in
            let notification = AXNotificationStream(
                app: xcode.runningApplication,
                notificationNames: kAXFocusedUIElementChangedNotification
            )
            for await _ in notification {
                try Task.checkCancellation()
                setFocusedElement()
            }
        }

        activeXcodeObservations.insert(focusedElementChanged)

        xcode.$completionPanel.sink { [weak self] element in
            self?.completionPanel = element
        }.store(in: &activeXcodeCancellable)

        xcode.$documentURL.sink { [weak self] url in
            self?.activeDocumentURL = url
        }.store(in: &activeXcodeCancellable)

        xcode.$projectURL.sink { [weak self] url in
            self?.activeProjectURL = url
        }.store(in: &activeXcodeCancellable)

        xcode.$focusedWindow.sink { [weak self] window in
            self?.focusedWindow = window
        }.store(in: &activeXcodeCancellable)
    }
}

// MARK: - AppInstanceInspector

public class AppInstanceInspector: ObservableObject {
    public let appElement: AXUIElement
    public let runningApplication: NSRunningApplication
    public var isActive: Bool { runningApplication.isActive }

    init(runningApplication: NSRunningApplication) {
        self.runningApplication = runningApplication
        appElement = AXUIElementCreateApplication(runningApplication.processIdentifier)
    }
}

// MARK: - XcodeAppInstanceInspector

public final class XcodeAppInstanceInspector: AppInstanceInspector {
    @Published public var focusedWindow: XcodeWindowInspector?
    @Published public var documentURL: URL = .init(fileURLWithPath: "/")
    @Published public var projectURL: URL = .init(fileURLWithPath: "/")
    @Published public var workspaces = [WorkspaceIdentifier: Workspace]()
    public var realtimeWorkspaces: [WorkspaceIdentifier: WorkspaceInfo] {
        updateWorkspaceInfo()
        return workspaces.mapValues(\.info)
    }

    @Published public private(set) var completionPanel: AXUIElement?

    public var realtimeDocumentURL: URL {
        guard let window = appElement.focusedWindow,
              window.identifier == "Xcode.WorkspaceWindow"
        else {
            return URL(fileURLWithPath: "/")
        }

        return WorkspaceXcodeWindowInspector.extractDocumentURL(windowElement: window)
            ?? URL(fileURLWithPath: "/")
    }

    var _version: String?
    public var version: String? {
        if let _version { return _version }
        guard let plistPath = runningApplication.bundleURL?
            .appendingPathComponent("Contents")
            .appendingPathComponent("version.plist")
            .path
        else { return nil }
        guard let plistData = FileManager.default.contents(atPath: plistPath) else { return nil }
        var format = PropertyListSerialization.PropertyListFormat.xml
        guard let plistDict = try? PropertyListSerialization.propertyList(
            from: plistData,
            options: .mutableContainersAndLeaves,
            format: &format
        ) as? [String: AnyObject] else { return nil }
        let result = plistDict["CFBundleShortVersionString"] as? String
        _version = result
        return result
    }

    private var longRunningTasks = Set<Task<Void, Error>>()
    private var focusedWindowObservations = Set<AnyCancellable>()

    deinit {
        for task in longRunningTasks { task.cancel() }
    }

    override init(runningApplication: NSRunningApplication) {
        super.init(runningApplication: runningApplication)

        observeFocusedWindow()
        observeAXNotifications()

        Task {
            try await Task.sleep(nanoseconds: 3_000_000_000)
            // Sometimes the focused window may not be ready on app launch.
            if !(focusedWindow is WorkspaceXcodeWindowInspector) {
                observeFocusedWindow()
            }
        }
    }

    func observeFocusedWindow() {
        if let window = appElement.focusedWindow {
            if window.identifier == "Xcode.WorkspaceWindow" {
                let window = WorkspaceXcodeWindowInspector(
                    app: runningApplication,
                    uiElement: window
                )
                focusedWindow = window

                // should find a better solution to do this thread safe
                Task { @MainActor in
                    focusedWindowObservations.forEach { $0.cancel() }
                    focusedWindowObservations.removeAll()

                    documentURL = window.documentURL
                    projectURL = window.projectURL

                    window.$documentURL
                        .filter { $0 != .init(fileURLWithPath: "/") }
                        .sink { [weak self] url in
                            self?.documentURL = url
                        }.store(in: &focusedWindowObservations)
                    window.$projectURL
                        .filter { $0 != .init(fileURLWithPath: "/") }
                        .sink { [weak self] url in
                            self?.projectURL = url
                        }.store(in: &focusedWindowObservations)
                }
            } else {
                let window = XcodeWindowInspector(uiElement: window)
                focusedWindow = window
            }
        } else {
            focusedWindow = nil
        }
    }

    func refresh() {
        if let focusedWindow = focusedWindow as? WorkspaceXcodeWindowInspector {
            focusedWindow.refresh()
        } else {
            observeFocusedWindow()
        }
    }

    func observeAXNotifications() {
        longRunningTasks.forEach { $0.cancel() }
        longRunningTasks = []

        let focusedWindowChanged = Task {
            let notification = AXNotificationStream(
                app: runningApplication,
                notificationNames: kAXFocusedWindowChangedNotification
            )
            for await _ in notification {
                try Task.checkCancellation()
                observeFocusedWindow()
            }
        }

        longRunningTasks.insert(focusedWindowChanged)

        updateWorkspaceInfo()
        let updateTabsTask = Task { @MainActor in
            let notification = AXNotificationStream(
                app: runningApplication,
                notificationNames: kAXFocusedUIElementChangedNotification,
                kAXApplicationDeactivatedNotification
            )
            if #available(macOS 13.0, *) {
                for await _ in notification.debounce(for: .seconds(2)) {
                    try Task.checkCancellation()
                    updateWorkspaceInfo()
                }
            } else {
                for await _ in notification {
                    try Task.checkCancellation()
                    updateWorkspaceInfo()
                }
            }
        }

        longRunningTasks.insert(updateTabsTask)

        let completionPanelTask = Task {
            let stream = AXNotificationStream(
                app: runningApplication,
                notificationNames: kAXCreatedNotification, kAXUIElementDestroyedNotification
            )

            for await event in stream {
                // We can only observe the creation and closing of the parent
                // of the completion panel.
                let isCompletionPanel = {
                    event.element.firstChild { element in
                        element.identifier == "_XC_COMPLETION_TABLE_"
                    } != nil
                }
                switch event.name {
                case kAXCreatedNotification:
                    if isCompletionPanel() {
                        completionPanel = event.element
                    }
                case kAXUIElementDestroyedNotification:
                    if isCompletionPanel() {
                        completionPanel = nil
                    }
                default: break
                }

                try Task.checkCancellation()
            }
        }

        longRunningTasks.insert(completionPanelTask)
    }
}

// MARK: - Workspace Info

extension XcodeAppInstanceInspector {
    public enum WorkspaceIdentifier: Hashable {
        case url(URL)
        case unknown
    }

    public class Workspace {
        public let element: AXUIElement
        public var info: WorkspaceInfo

        /// When a window is closed, all it's properties will be set to nil.
        /// Since we can't get notification for window closing,
        /// we will use it to check if the window is closed.
        var isValid: Bool {
            element.parent != nil
        }

        init(element: AXUIElement) {
            self.element = element
            info = .init(tabs: [])
        }
    }

    public struct WorkspaceInfo {
        public let tabs: Set<String>

        public func combined(with info: WorkspaceInfo) -> WorkspaceInfo {
            return .init(tabs: tabs.union(info.tabs))
        }
    }

    func updateWorkspaceInfo() {
        let workspaceInfoInVisibleSpace = Self.fetchVisibleWorkspaces(runningApplication)
        workspaces = Self.updateWorkspace(workspaces, with: workspaceInfoInVisibleSpace)
    }

    /// Use the project path as the workspace identifier.
    static func workspaceIdentifier(_ window: AXUIElement) -> WorkspaceIdentifier {
        for child in window.children {
            if child.description.starts(with: "/"), child.description.count > 1 {
                let path = child.description
                let trimmedNewLine = path.trimmingCharacters(in: .newlines)
                var url = URL(fileURLWithPath: trimmedNewLine)
                while !FileManager.default.fileIsDirectory(atPath: url.path) ||
                    !url.pathExtension.isEmpty
                {
                    url = url.deletingLastPathComponent()
                }
                return WorkspaceIdentifier.url(url)
            }
        }
        return WorkspaceIdentifier.unknown
    }

    /// With Accessibility API, we can ONLY get the information of visible windows.
    static func fetchVisibleWorkspaces(
        _ app: NSRunningApplication
    ) -> [WorkspaceIdentifier: Workspace] {
        let app = AXUIElementCreateApplication(app.processIdentifier)
        let windows = app.windows.filter { $0.identifier == "Xcode.WorkspaceWindow" }

        var dict = [WorkspaceIdentifier: Workspace]()

        for window in windows {
            let workspaceIdentifier = workspaceIdentifier(window)

            let tabs = {
                guard let editArea = window.firstChild(where: { $0.description == "editor area" })
                else { return Set<String>() }
                var allTabs = Set<String>()
                let tabBars = editArea.children { $0.description == "tab bar" }
                for tabBar in tabBars {
                    let tabs = tabBar.children { $0.roleDescription == "tab" }
                    for tab in tabs {
                        allTabs.insert(tab.title)
                    }
                }
                return allTabs
            }()

            let workspace = Workspace(element: window)
            workspace.info = .init(tabs: tabs)
            dict[workspaceIdentifier] = workspace
        }
        return dict
    }

    static func updateWorkspace(
        _ old: [WorkspaceIdentifier: Workspace],
        with new: [WorkspaceIdentifier: Workspace]
    ) -> [WorkspaceIdentifier: Workspace] {
        var updated = old.filter { $0.value.isValid } // remove closed windows.
        for (identifier, workspace) in new {
            if let existed = updated[identifier] {
                existed.info = workspace.info
            } else {
                updated[identifier] = workspace
            }
        }
        return updated
    }
}

