import AppKit
import AsyncPassthroughSubject
import AXExtension
import AXNotificationStream
import Combine
import Foundation

public final class XcodeAppInstanceInspector: AppInstanceInspector {
    public struct AXNotification {
        public var kind: AXNotificationKind
        public var element: AXUIElement
    }

    public enum AXNotificationKind {
        case titleChanged
        case applicationActivated
        case applicationDeactivated
        case moved
        case resized
        case mainWindowChanged
        case focusedWindowChanged
        case focusedUIElementChanged
        case windowMoved
        case windowResized
        case windowMiniaturized
        case windowDeminiaturized
        case created
        case uiElementDestroyed
        case xcodeCompletionPanelChanged

        public init?(rawValue: String) {
            switch rawValue {
            case kAXTitleChangedNotification:
                self = .titleChanged
            case kAXApplicationActivatedNotification:
                self = .applicationActivated
            case kAXApplicationDeactivatedNotification:
                self = .applicationDeactivated
            case kAXMovedNotification:
                self = .moved
            case kAXResizedNotification:
                self = .resized
            case kAXMainWindowChangedNotification:
                self = .mainWindowChanged
            case kAXFocusedWindowChangedNotification:
                self = .focusedWindowChanged
            case kAXFocusedUIElementChangedNotification:
                self = .focusedUIElementChanged
            case kAXWindowMovedNotification:
                self = .windowMoved
            case kAXWindowResizedNotification:
                self = .windowResized
            case kAXWindowMiniaturizedNotification:
                self = .windowMiniaturized
            case kAXWindowDeminiaturizedNotification:
                self = .windowDeminiaturized
            case kAXCreatedNotification:
                self = .created
            case kAXUIElementDestroyedNotification:
                self = .uiElementDestroyed
            default:
                return nil
            }
        }
    }

    @Published public fileprivate(set) var focusedWindow: XcodeWindowInspector?
    @Published public fileprivate(set) var documentURL: URL? = nil
    @Published public fileprivate(set) var workspaceURL: URL? = nil
    @Published public fileprivate(set) var projectRootURL: URL? = nil
    @Published public fileprivate(set) var workspaces = [WorkspaceIdentifier: Workspace]()
    @Published public private(set) var completionPanel: AXUIElement?
    public var realtimeWorkspaces: [WorkspaceIdentifier: WorkspaceInfo] {
        updateWorkspaceInfo()
        return workspaces.mapValues(\.info)
    }

    public let axNotifications = AsyncPassthroughSubject<AXNotification>()

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
        axNotifications.finish()
        for task in longRunningTasks { task.cancel() }
    }

    override init(runningApplication: NSRunningApplication) {
        super.init(runningApplication: runningApplication)

        Task { @XcodeInspectorActor in
            observeFocusedWindow()
            observeAXNotifications()

            try await Task.sleep(nanoseconds: 3_000_000_000)
            // Sometimes the focused window may not be ready on app launch.
            if !(focusedWindow is WorkspaceXcodeWindowInspector) {
                observeFocusedWindow()
            }
        }
    }

    @XcodeInspectorActor
    func refresh() {
        if let focusedWindow = focusedWindow as? WorkspaceXcodeWindowInspector {
            focusedWindow.refresh()
        } else {
            observeFocusedWindow()
        }
    }

    @XcodeInspectorActor
    private func observeFocusedWindow() {
        if let window = appElement.focusedWindow {
            if window.identifier == "Xcode.WorkspaceWindow" {
                let window = WorkspaceXcodeWindowInspector(
                    app: runningApplication,
                    uiElement: window,
                    axNotifications: axNotifications
                )

                focusedWindowObservations.forEach { $0.cancel() }
                focusedWindowObservations.removeAll()

                Task { @MainActor in
                    focusedWindow = window
                    documentURL = window.documentURL
                    workspaceURL = window.workspaceURL
                    projectRootURL = window.projectRootURL
                }

                window.$documentURL
                    .filter { $0 != .init(fileURLWithPath: "/") }
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] url in
                        self?.documentURL = url
                    }.store(in: &focusedWindowObservations)
                window.$workspaceURL
                    .filter { $0 != .init(fileURLWithPath: "/") }
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] url in
                        self?.workspaceURL = url
                    }.store(in: &focusedWindowObservations)
                window.$projectRootURL
                    .filter { $0 != .init(fileURLWithPath: "/") }
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] url in
                        self?.projectRootURL = url
                    }.store(in: &focusedWindowObservations)

            } else {
                let window = XcodeWindowInspector(uiElement: window)
                Task { @MainActor in
                    focusedWindow = window
                }
            }
        } else {
            Task { @MainActor in
                focusedWindow = nil
            }
        }
    }

    @XcodeInspectorActor
    func observeAXNotifications() {
        longRunningTasks.forEach { $0.cancel() }
        longRunningTasks = []

        let axNotificationStream = AXNotificationStream(
            app: runningApplication,
            notificationNames:
            kAXTitleChangedNotification,
            kAXApplicationActivatedNotification,
            kAXApplicationDeactivatedNotification,
            kAXMovedNotification,
            kAXResizedNotification,
            kAXMainWindowChangedNotification,
            kAXFocusedWindowChangedNotification,
            kAXFocusedUIElementChangedNotification,
            kAXWindowMovedNotification,
            kAXWindowResizedNotification,
            kAXWindowMiniaturizedNotification,
            kAXWindowDeminiaturizedNotification,
            kAXCreatedNotification,
            kAXUIElementDestroyedNotification
        )

        let observeAXNotificationTask = Task { @XcodeInspectorActor [weak self] in
            var updateWorkspaceInfoTask: Task<Void, Error>?

            for await notification in axNotificationStream {
                guard let self else { return }
                try Task.checkCancellation()
                await Task.yield()

                guard let event = AXNotificationKind(rawValue: notification.name) else {
                    continue
                }

                self.axNotifications.send(.init(kind: event, element: notification.element))

                if event == .focusedWindowChanged {
                    observeFocusedWindow()
                }

                if event == .focusedUIElementChanged || event == .applicationDeactivated {
                    updateWorkspaceInfoTask?.cancel()
                    updateWorkspaceInfoTask = Task { [weak self] in
                        guard let self else { return }
                        try await Task.sleep(nanoseconds: 2_000_000_000)
                        try Task.checkCancellation()
                        self.updateWorkspaceInfo()
                    }
                }

                if event == .created || event == .uiElementDestroyed {
                    switch event {
                    case .created:
                        if isCompletionPanel(notification.element) {
                            await MainActor.run {
                                self.completionPanel = notification.element
                                self.completionPanel?.setMessagingTimeout(1)
                                self.axNotifications.send(.init(
                                    kind: .xcodeCompletionPanelChanged,
                                    element: notification.element
                                ))
                            }
                        }
                    case .uiElementDestroyed:
                        if isCompletionPanel(notification.element) {
                            await MainActor.run {
                                self.completionPanel = nil
                                self.axNotifications.send(.init(
                                    kind: .xcodeCompletionPanelChanged,
                                    element: notification.element
                                ))
                            }
                        }
                    default: continue
                    }
                }
            }
        }

        longRunningTasks.insert(observeAXNotificationTask)

        updateWorkspaceInfo()
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
        let workspaces = Self.updateWorkspace(workspaces, with: workspaceInfoInVisibleSpace)
        Task { @MainActor in
            self.workspaces = workspaces
        }
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
            var traverseCount = 0

            let tabs = {
                guard let editArea = window.firstChild(where: { $0.description == "editor area" })
                else { return Set<String>() }
                var allTabs = Set<String>()
                let tabBars = editArea.tabBars
                for tabBar in tabBars {
                    tabBar.traverse { element, _ in
                        traverseCount += 1
                        if element.roleDescription == "tab" {
                            allTabs.insert(element.title)
                            return .skipDescendants
                        }
                        return .continueSearching
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

private func isCompletionPanel(_ element: AXUIElement) -> Bool {
    let matchXcode15CompletionPanel =
        element.firstChild { element in
            element.identifier == "_XC_COMPLETION_TABLE_"
        } != nil

    if matchXcode15CompletionPanel {
        return true
    }

    let matchXcode16CompletionPanel = {
        if element.parent?.parent != nil { return false }
        if element.role != "AXWindow" { return false }
        if element.roleDescription != "dialog" { return false }
        guard let group = element.firstChild(where: { $0.role == "AXGroup" }),
              let scrollArea = group.firstChild(where: { $0.role == "AXScrollArea" }),
              let list = scrollArea.firstChild(where: { $0.role == "AXOpaqueProviderGroup" }),
              let _ = list.children.first(where: { $0.value == "code completion" })
        else { return false }
        return true
    }()

    return matchXcode16CompletionPanel
}

public extension AXUIElement {
    var tabBars: [AXUIElement] {
        // Searching by traversing with AXUIElement is (Xcode) resource consuming, we should skip
        // as much as possible!
        
        guard let editArea: AXUIElement = {
            if description == "editor area" { return self }
            return firstChild(where: { $0.description == "editor area" })
        }() else { return [] }
        
        var tabBars = [AXUIElement]()
        editArea.traverse { element, _ in
            let description = element.description
            if description == "Tab Bar" {
                element.traverse { element, _ in
                    if element.description == "tab bar" {
                        tabBars.append(element)
                        return .stopSearching
                    }
                    return .continueSearching
                }

                return .skipDescendantsAndSiblings
            }
            
            if element.identifier == "editor context" {
                return .skipDescendantsAndSiblings
            }

            if element.isSourceEditor {
                return .skipDescendantsAndSiblings
            }

            if description == "Code Coverage Ribbon" {
                return .skipDescendants
            }

            if description == "Debug Area" {
                return .skipDescendants
            }
            
            if description == "debug bar" {
                return .skipDescendants
            }

            return .continueSearching
        }

        return tabBars
    }
}
