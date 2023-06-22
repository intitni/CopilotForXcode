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

    @Published public internal(set) var activeApplication: AppInstanceInspector?
    @Published public internal(set) var activeXcode: XcodeAppInstanceInspector?
    @Published public internal(set) var latestActiveXcode: XcodeAppInstanceInspector?
    @Published public internal(set) var xcodes: [XcodeAppInstanceInspector] = []
    @Published public internal(set) var activeProjectURL = URL(fileURLWithPath: "/")
    @Published public internal(set) var activeDocumentURL = URL(fileURLWithPath: "/")
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
        activeDocumentURL = xcode.documentURL
        activeProjectURL = xcode.projectURL
        focusedWindow = xcode.focusedWindow

        xcode.$documentURL.filter { _ in xcode.isActive }.assign(to: &$activeDocumentURL)
        xcode.$projectURL.filter { _ in xcode.isActive }.assign(to: &$activeProjectURL)
        xcode.$focusedWindow.filter { _ in xcode.isActive }.assign(to: &$focusedWindow)
    }

    func setActiveXcode(_ xcode: XcodeAppInstanceInspector) {
        for task in activeXcodeObservations { task.cancel() }
        activeXcodeObservations.removeAll()

        activeXcode = xcode
        latestActiveXcode = xcode
        activeDocumentURL = xcode.documentURL
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
    }
}

public class AppInstanceInspector: ObservableObject {
    public let appElement: AXUIElement
    public let runningApplication: NSRunningApplication
    public var isActive: Bool { runningApplication.isActive }

    init(runningApplication: NSRunningApplication) {
        self.runningApplication = runningApplication
        appElement = AXUIElementCreateApplication(runningApplication.processIdentifier)
    }
}

public final class XcodeAppInstanceInspector: AppInstanceInspector {
    public struct WorkspaceInfo {
        public let tabs: Set<String>

        public func combined(with info: WorkspaceInfo) -> WorkspaceInfo {
            return .init(tabs: info.tabs.union(tabs))
        }
    }

    public enum WorkspaceIdentifier: Hashable {
        case url(URL)
        case unknown
    }

    @Published public var focusedWindow: XcodeWindowInspector?
    @Published public var documentURL: URL = .init(fileURLWithPath: "/")
    @Published public var projectURL: URL = .init(fileURLWithPath: "/")
    @Published public var workspaces = [WorkspaceIdentifier: WorkspaceInfo]()
    @Published public private(set) var completionPanel: AXUIElement?
    
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

        workspaces = Self.fetchWorkspaceInfo(runningApplication)
        let updateTabsTask = Task { @MainActor in
            let notification = AXNotificationStream(
                app: runningApplication,
                notificationNames: kAXFocusedUIElementChangedNotification,
                kAXApplicationDeactivatedNotification
            )
            if #available(macOS 13.0, *) {
                for await _ in notification.debounce(for: .seconds(5)) {
                    try Task.checkCancellation()
                    workspaces = Self.fetchWorkspaceInfo(runningApplication)
                }
            } else {
                for await _ in notification {
                    try Task.checkCancellation()
                    workspaces = Self.fetchWorkspaceInfo(runningApplication)
                }
            }
        }

        longRunningTasks.insert(updateTabsTask)
        
        completionPanel = appElement.firstChild { element in
            element.identifier == "_XC_COMPLETION_TABLE_"
        }?.parent

        let completionPanelTask = Task {
            let stream = AXNotificationStream(
                app: runningApplication,
                element: appElement,
                notificationNames: kAXCreatedNotification, kAXUIElementDestroyedNotification
            )
            
            for await event in stream {
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

    func observeFocusedWindow() {
        if let window = appElement.focusedWindow {
            if window.identifier == "Xcode.WorkspaceWindow" {
                let window = WorkspaceXcodeWindowInspector(
                    app: runningApplication,
                    uiElement: window
                )
                focusedWindow = window
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
            } else {
                let window = XcodeWindowInspector(uiElement: window)
                focusedWindow = window
            }
        } else {
            focusedWindow = nil
        }
    }

    static func fetchWorkspaceInfo(
        _ app: NSRunningApplication
    ) -> [WorkspaceIdentifier: WorkspaceInfo] {
        let app = AXUIElementCreateApplication(app.processIdentifier)
        let windows = app.windows.filter { $0.identifier == "Xcode.WorkspaceWindow" }

        var dict = [WorkspaceIdentifier: WorkspaceInfo]()

        for window in windows {
            let workspaceIdentifier = {
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
            }()

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

            dict[workspaceIdentifier] = .init(tabs: tabs)
        }

        return dict
    }
}

