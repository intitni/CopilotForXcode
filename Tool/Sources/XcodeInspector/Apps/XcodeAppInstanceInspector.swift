@preconcurrency import AppKit
import AsyncPassthroughSubject
import AXExtension
import AXNotificationStream
import Combine
import Foundation
import Perception

@XcodeInspectorActor
@Perceptible
public final class XcodeAppInstanceInspector: AppInstanceInspector, @unchecked Sendable {
    public struct AXNotification: Sendable {
        public var kind: AXNotificationKind
        public var element: AXUIElement
    }

    public enum AXNotificationKind: Sendable {
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

    @MainActor
    public fileprivate(set) var focusedWindow: XcodeWindowInspector? {
        didSet {
            if runningApplication.isActive {
                NotificationCenter.default.post(name: .focusedWindowDidChange, object: self)
            }
        }
    }

    @MainActor
    public fileprivate(set) var documentURL: URL? = nil {
        didSet {
            if runningApplication.isActive {
                NotificationCenter.default.post(name: .activeDocumentURLDidChange, object: self)
            }
        }
    }

    @MainActor
    public fileprivate(set) var workspaceURL: URL? = nil {
        didSet {
            if runningApplication.isActive {
                NotificationCenter.default.post(name: .activeWorkspaceURLDidChange, object: self)
            }
        }
    }

    @MainActor
    public fileprivate(set) var projectRootURL: URL? = nil {
        didSet {
            if runningApplication.isActive {
                NotificationCenter.default.post(name: .activeProjectRootURLDidChange, object: self)
            }
        }
    }

    @MainActor
    public fileprivate(set) var workspaces = [WorkspaceIdentifier: Workspace]() {
        didSet {
            if runningApplication.isActive {
                NotificationCenter.default.post(name: .xcodeWorkspacesDidChange, object: self)
            }
        }
    }

    @MainActor
    public private(set) var completionPanel: AXUIElement? {
        didSet {
            if runningApplication.isActive {
                NotificationCenter.default.post(name: .completionPanelDidChange, object: self)
            }
        }
    }

    private let observer = XcodeInspector.createObserver()

    public nonisolated var realtimeWorkspaces: [WorkspaceIdentifier: WorkspaceInfo] {
        Self.fetchVisibleWorkspaces(runningApplication).mapValues { $0.info }
    }

    public nonisolated let axNotifications = AsyncPassthroughSubject<AXNotification>()

    public nonisolated
    var realtimeDocumentURL: URL? {
        guard let window = appElement.focusedWindow,
              window.identifier == "Xcode.WorkspaceWindow"
        else { return nil }

        return WorkspaceXcodeWindowInspector.extractDocumentURL(windowElement: window)
    }

    public nonisolated
    var realtimeWorkspaceURL: URL? {
        guard let window = appElement.focusedWindow,
              window.identifier == "Xcode.WorkspaceWindow"
        else { return nil }

        return WorkspaceXcodeWindowInspector.extractWorkspaceURL(windowElement: window)
    }

    public nonisolated
    var realtimeProjectURL: URL? {
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

    @PerceptionIgnored private var longRunningTasks = Set<Task<Void, Error>>()

    deinit {
        axNotifications.finish()
        for task in longRunningTasks { task.cancel() }
    }

    override init(runningApplication: NSRunningApplication) {
        super.init(runningApplication: runningApplication)

        Task { @XcodeInspectorActor in
            await observeFocusedWindow()
            observeAXNotifications()

            try await Task.sleep(nanoseconds: 3_000_000_000)
            // Sometimes the focused window may not be ready on app launch.
            if await !(focusedWindow is WorkspaceXcodeWindowInspector) {
                await observeFocusedWindow()
            }
        }
    }

    func refresh() {
        Task { @MainActor in
            if let focusedWindow = focusedWindow as? WorkspaceXcodeWindowInspector {
                await focusedWindow.refresh()
            } else {
                observeFocusedWindow()
            }
        }
    }

    @MainActor
    private func observeFocusedWindow() {
        if let window = appElement.focusedWindow {
            if window.identifier == "Xcode.WorkspaceWindow" {
                let window = WorkspaceXcodeWindowInspector(
                    app: runningApplication,
                    uiElement: window,
                    axNotifications: axNotifications
                )

                focusedWindow = window
                documentURL = window.documentURL
                workspaceURL = window.workspaceURL
                projectRootURL = window.projectRootURL

                observer.observe { [weak self] in
                    let url = window.documentURL
                    if url != .init(fileURLWithPath: "/") {
                        self?.documentURL = url
                    }
                }

                observer.observe { [weak self] in
                    let url = window.workspaceURL
                    if url != .init(fileURLWithPath: "/") {
                        self?.workspaceURL = url
                    }
                }

                observer.observe { [weak self] in
                    let url = window.projectRootURL
                    if url != .init(fileURLWithPath: "/") {
                        self?.projectRootURL = url
                    }
                }
            } else {
                let window = XcodeWindowInspector(uiElement: window)
                focusedWindow = window
            }
        } else {
            focusedWindow = nil
        }
    }

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
                    await observeFocusedWindow()
                }

                if event == .focusedUIElementChanged || event == .applicationDeactivated {
                    updateWorkspaceInfoTask?.cancel()
                    updateWorkspaceInfoTask = Task { [weak self] in
                        guard let self else { return }
                        try await Task.sleep(nanoseconds: 2_000_000_000)
                        try Task.checkCancellation()
                        await self.updateWorkspaceInfo()
                    }
                }

                if event == .created || event == .uiElementDestroyed {
                    switch event {
                    case .created:
                        if isCompletionPanel(notification.element) {
                            await MainActor.run {
                                self.completionPanel = notification.element
                                self.completionPanel?.setMessagingTimeout(1)
                            }
                            self.axNotifications.send(.init(
                                kind: .xcodeCompletionPanelChanged,
                                element: notification.element
                            ))
                        }
                    case .uiElementDestroyed:
                        if isCompletionPanel(notification.element) {
                            await MainActor.run {
                                self.completionPanel = nil
                            }
                            self.axNotifications.send(.init(
                                kind: .xcodeCompletionPanelChanged,
                                element: notification.element
                            ))
                        }
                    default: continue
                    }
                }
            }
        }

        longRunningTasks.insert(observeAXNotificationTask)

        Task { @MainActor in
            updateWorkspaceInfo()
        }
    }
}

// MARK: - Workspace Info

extension XcodeAppInstanceInspector {
    public enum WorkspaceIdentifier: Hashable, Sendable {
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

    public struct WorkspaceInfo: Sendable {
        public let tabs: Set<String>

        public func combined(with info: WorkspaceInfo) -> WorkspaceInfo {
            return .init(tabs: tabs.union(info.tabs))
        }
    }

    @MainActor
    func updateWorkspaceInfo() {
        let workspaceInfoInVisibleSpace = Self.fetchVisibleWorkspaces(runningApplication)
        let workspaces = Self.updateWorkspace(workspaces, with: workspaceInfoInVisibleSpace)
        self.workspaces = workspaces
    }

    /// Use the project path as the workspace identifier.
    nonisolated static func workspaceIdentifier(_ window: AXUIElement) -> WorkspaceIdentifier {
        if let url = WorkspaceXcodeWindowInspector.extractWorkspaceURL(windowElement: window) {
            return WorkspaceIdentifier.url(url)
        }
        return WorkspaceIdentifier.unknown
    }

    /// With Accessibility API, we can ONLY get the information of visible windows.
    nonisolated static func fetchVisibleWorkspaces(
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

    nonisolated static func updateWorkspace(
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

    var debugArea: AXUIElement? {
        guard let editArea: AXUIElement = {
            if description == "editor area" { return self }
            return firstChild(where: { $0.description == "editor area" })
        }() else { return nil }

        var debugArea: AXUIElement?
        editArea.traverse { element, _ in
            let description = element.description
            if description == "Tab Bar" {
                return .skipDescendants
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
                debugArea = element
                return .skipDescendants
            }

            if description == "debug bar" {
                return .skipDescendants
            }

            return .continueSearching
        }

        return debugArea
    }
}

