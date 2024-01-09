import AppKit
import AsyncAlgorithms
import AXExtension
import AXNotificationStream
import Combine
import Foundation
import Logger
import Preferences
import SuggestionModel

public final class XcodeInspector: ObservableObject {
    public static let shared = XcodeInspector()

    private var cancellable = Set<AnyCancellable>()
    private var activeXcodeObservations = Set<Task<Void, Error>>()
    private var activeXcodeCancellable = Set<AnyCancellable>()

    @Published public internal(set) var activeApplication: AppInstanceInspector?
    @Published public internal(set) var previousActiveApplication: AppInstanceInspector?
    @Published public internal(set) var activeXcode: XcodeAppInstanceInspector?
    @Published public internal(set) var latestActiveXcode: XcodeAppInstanceInspector?
    @Published public internal(set) var xcodes: [XcodeAppInstanceInspector] = []
    @Published public internal(set) var activeProjectRootURL: URL? = nil
    @Published public internal(set) var activeDocumentURL: URL? = nil
    @Published public internal(set) var activeWorkspaceURL: URL? = nil
    @Published public internal(set) var focusedWindow: XcodeWindowInspector?
    @Published public internal(set) var focusedEditor: SourceEditor?
    @Published public internal(set) var focusedElement: AXUIElement?
    @Published public internal(set) var completionPanel: AXUIElement?

    public var focusedEditorContent: EditorInformation? {
        guard let documentURL = XcodeInspector.shared.realtimeActiveDocumentURL,
              let workspaceURL = XcodeInspector.shared.realtimeActiveWorkspaceURL,
              let projectURL = XcodeInspector.shared.activeProjectRootURL
        else { return nil }

        let editorContent = XcodeInspector.shared.focusedEditor?.content
        let language = languageIdentifierFromFileURL(documentURL)
        let relativePath = documentURL.path.replacingOccurrences(of: projectURL.path, with: "")

        if let editorContent, let range = editorContent.selections.first {
            let (selectedContent, selectedLines) = EditorInformation.code(
                in: editorContent.lines,
                inside: range
            )
            return .init(
                editorContent: editorContent,
                selectedContent: selectedContent,
                selectedLines: selectedLines,
                documentURL: documentURL,
                workspaceURL: workspaceURL,
                projectRootURL: projectURL,
                relativePath: relativePath,
                language: language
            )
        }

        return .init(
            editorContent: editorContent,
            selectedContent: "",
            selectedLines: [],
            documentURL: documentURL,
            workspaceURL: workspaceURL,
            projectRootURL: projectURL,
            relativePath: relativePath,
            language: language
        )
    }

    public var realtimeActiveDocumentURL: URL? {
        latestActiveXcode?.realtimeDocumentURL ?? activeDocumentURL
    }

    public var realtimeActiveWorkspaceURL: URL? {
        latestActiveXcode?.realtimeWorkspaceURL ?? activeWorkspaceURL
    }

    public var realtimeActiveProjectURL: URL? {
        latestActiveXcode?.realtimeProjectURL ?? activeWorkspaceURL
    }

    init() {
        let runningApplications = NSWorkspace.shared.runningApplications
        xcodes = runningApplications
            .filter { $0.isXcode }
            .map(XcodeAppInstanceInspector.init(runningApplication:))
        let activeXcode = xcodes.first(where: \.isActive)
        latestActiveXcode = activeXcode ?? xcodes.first
        activeApplication = activeXcode ?? runningApplications
            .first(where: \.isActive)
            .map(AppInstanceInspector.init(runningApplication:))

        Task { // Did activate app
            if let activeXcode {
                await setActiveXcode(activeXcode)
            }

            let sequence = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didActivateApplicationNotification)
            for await notification in sequence {
                try Task.checkCancellation()
                guard let app = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { continue }
                if app.isXcode {
                    if let existed = xcodes.first(where: {
                        $0.runningApplication.processIdentifier == app.processIdentifier
                    }) {
                        await MainActor.run {
                            setActiveXcode(existed)
                        }
                    } else {
                        let new = XcodeAppInstanceInspector(runningApplication: app)
                        await MainActor.run {
                            xcodes.append(new)
                            setActiveXcode(new)
                        }
                    }
                } else {
                    let appInspector = AppInstanceInspector(runningApplication: app)
                    await MainActor.run {
                        previousActiveApplication = activeApplication
                        activeApplication = appInspector
                    }
                }
            }
        }

        Task { // Did terminate app
            let sequence = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didTerminateApplicationNotification)
            for await notification in sequence {
                try Task.checkCancellation()
                guard let app = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { continue }
                if app.isXcode {
                    let processIdentifier = app.processIdentifier
                    await MainActor.run {
                        xcodes.removeAll {
                            $0.runningApplication.processIdentifier == processIdentifier
                        }
                        if latestActiveXcode?.runningApplication
                            .processIdentifier == processIdentifier
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
    }

    @MainActor
    func setActiveXcode(_ xcode: XcodeAppInstanceInspector) {
        previousActiveApplication = activeApplication
        activeApplication = xcode
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
        activeProjectRootURL = xcode.projectRootURL
        activeWorkspaceURL = xcode.workspaceURL
        focusedWindow = xcode.focusedWindow

        let setFocusedElement = { [weak self] in
            guard let self else { return }
            focusedElement = xcode.appElement.focusedElement
            if let editorElement = focusedElement, editorElement.isSourceEditor {
                focusedEditor = .init(
                    runningApplication: xcode.runningApplication,
                    element: editorElement
                )
            } else if let element = focusedElement,
                      let editorElement = element.firstParent(where: \.isSourceEditor)
            {
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

        xcode.$workspaceURL.sink { [weak self] url in
            self?.activeWorkspaceURL = url
        }.store(in: &activeXcodeCancellable)

        xcode.$projectRootURL.sink { [weak self] url in
            self?.activeProjectRootURL = url
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
    public var isXcode: Bool { runningApplication.isXcode }
    public var isExtensionService: Bool { runningApplication.isCopilotForXcodeExtensionService }

    init(runningApplication: NSRunningApplication) {
        self.runningApplication = runningApplication
        appElement = AXUIElementCreateApplication(runningApplication.processIdentifier)
    }
}

// MARK: - XcodeAppInstanceInspector

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

// MARK: - Triggering Command

public extension XcodeAppInstanceInspector {
    func triggerCopilotCommand(name: String) async throws {
        let bundleName = Bundle.main
            .object(forInfoDictionaryKey: "EXTENSION_BUNDLE_NAME") as! String
        try await triggerMenuItem(path: ["Editor", bundleName, name])
    }
}

public extension AppInstanceInspector {
    func triggerMenuItem(path: [String]) async throws {
        guard !path.isEmpty else { return }

        struct CantRunCommand: Error, LocalizedError {
            let path: [String]
            var errorDescription: String? {
                "Can't run command \(path.joined(separator: "/"))."
            }
        }

        if !runningApplication.isActive { runningApplication.activate() }

        if UserDefaults.shared.value(for: \.triggerActionWithAccessibilityAPI) {
            let app = AXUIElementCreateApplication(runningApplication.processIdentifier)
            guard let menuBar = app.menuBar else { throw CantRunCommand(path: path) }
            var path = path
            var currentMenu = menuBar
            while !path.isEmpty {
                let item = path.removeFirst()

                if path.isEmpty, let button = currentMenu.child(title: item, role: "AXMenuItem") {
                    let error = AXUIElementPerformAction(button, kAXPressAction as CFString)
                    if error != AXError.success {
                        Logger.service.error("""
                        Trigger menu item \(path.joined(separator: "/")) failed: \
                        \(error.localizedDescription)
                        """)
                        throw error
                    } else {
                        return
                    }
                } else if let menu = currentMenu.child(title: item) {
                    currentMenu = menu
                } else {
                    throw CantRunCommand(path: path)
                }
            }
        } else {
            guard path.count >= 2 else { throw CantRunCommand(path: path) }

            let clickTask = {
                var path = path
                let button = path.removeLast()
                let menuBarItem = path.removeFirst()
                let list = path
                    .reversed()
                    .map { "menu 1 of menu item \"\($0)\"" }
                    .joined(separator: " of ")
                return """
                click menu item "\(button)" of \(list) \
                of menu bar item "\(menuBarItem)" \
                of menu bar 1
                """
            }()
            /// check if menu is open, if not, click the menu item.
            let appleScript = """
            tell application "System Events"
                set theprocs to every process whose unix id is \
                \(runningApplication.processIdentifier)
                repeat with proc in theprocs
                set the frontmost of proc to true
                    tell proc
                        repeat with theMenu in menus of menu bar 1
                            set theValue to value of attribute "AXVisibleChildren" of theMenu
                            if theValue is not {} then
                                return
                            end if
                        end repeat
                        \(clickTask)
                    end tell
                end repeat
            end tell
            """

            do {
                try await runAppleScript(appleScript)
            } catch {
                Logger.service.error("""
                Trigger menu item \(path.joined(separator: "/")) failed: \
                \(error.localizedDescription)
                """)
                throw error
            }
        }
    }
}

@discardableResult
func runAppleScript(_ appleScript: String) async throws -> String {
    let task = Process()
    task.launchPath = "/usr/bin/osascript"
    task.arguments = ["-e", appleScript]
    let outpipe = Pipe()
    task.standardOutput = outpipe
    task.standardError = Pipe()

    return try await withUnsafeThrowingContinuation { continuation in
        do {
            task.terminationHandler = { _ in
                do {
                    if let data = try outpipe.fileHandleForReading.readToEnd(),
                       let content = String(data: data, encoding: .utf8)
                    {
                        continuation.resume(returning: content)
                        return
                    }
                    continuation.resume(returning: "")
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            try task.run()
        } catch {
            continuation.resume(throwing: error)
        }
    }
}

