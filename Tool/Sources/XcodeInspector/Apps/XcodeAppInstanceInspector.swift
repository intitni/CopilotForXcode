import AppKit
import AXExtension
import AXNotificationStream
import Combine
import Foundation

public final class XcodeAppInstanceInspector: AppInstanceInspector {
    @Published public var focusedWindow: XcodeWindowInspector?
    @Published public var documentURL: URL? = nil
    @Published public var workspaceURL: URL? = nil
    @Published public var projectRootURL: URL? = nil
    @Published public var workspaces = [WorkspaceIdentifier: Workspace]()
    public var realtimeWorkspaces: [WorkspaceIdentifier: WorkspaceInfo] {
        updateWorkspaceInfo()
        return workspaces.mapValues(\.info)
    }

    @Published public private(set) var completionPanel: AXUIElement?

    public var realtimeDocumentURL: URL? {
        guard let window = appElement.focusedWindow,
              window.identifier == "Xcode.WorkspaceWindow"
        else { return nil }

        return WorkspaceXcodeWindowInspector.extractDocumentURL(windowElement: window)
    }

    public var realtimeWorkspaceURL: URL? {
        guard let window = appElement.focusedWindow,
              window.identifier == "Xcode.WorkspaceWindow"
        else { return nil }

        return WorkspaceXcodeWindowInspector.extractWorkspaceURL(windowElement: window)
    }

    public var realtimeProjectURL: URL? {
        let workspaceURL = realtimeWorkspaceURL
        let documentURL = realtimeDocumentURL
        return WorkspaceXcodeWindowInspector.extractProjectURL(
            workspaceURL: workspaceURL,
            documentURL: documentURL
        )
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
                    workspaceURL = window.workspaceURL
                    projectRootURL = window.projectRootURL

                    window.$documentURL
                        .filter { $0 != .init(fileURLWithPath: "/") }
                        .sink { [weak self] url in
                            self?.documentURL = url
                        }.store(in: &focusedWindowObservations)
                    window.$workspaceURL
                        .filter { $0 != .init(fileURLWithPath: "/") }
                        .sink { [weak self] url in
                            self?.workspaceURL = url
                        }.store(in: &focusedWindowObservations)
                    window.$projectRootURL
                        .filter { $0 != .init(fileURLWithPath: "/") }
                        .sink { [weak self] url in
                            self?.projectRootURL = url
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
        if let url = WorkspaceXcodeWindowInspector.extractWorkspaceURL(windowElement: window) {
            return WorkspaceIdentifier.url(url)
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

