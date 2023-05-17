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

        activeXcodeObservations.insert(focusedElementChanged)
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
    @Published var documentURL: URL = .init(fileURLWithPath: "/")
    @Published var projectURL: URL = .init(fileURLWithPath: "/")
    @Published var tabs: Set<String> = []
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

        if let updatedTabs = Self.findAvailableOpenedTabs(runningApplication) {
            tabs = updatedTabs
        }
        let updateTabsTask = Task { @MainActor in
            let notification = AXNotificationStream(
                app: runningApplication,
                notificationNames: kAXFocusedUIElementChangedNotification
            )
            if #available(macOS 13.0, *) {
                for await _ in notification.debounce(for: .seconds(5)) {
                    try Task.checkCancellation()
                    if let updatedTabs = Self.findAvailableOpenedTabs(runningApplication) {
                        tabs = updatedTabs
                    }
                }
            } else {
                for await _ in notification {
                    try Task.checkCancellation()
                    if let updatedTabs = Self.findAvailableOpenedTabs(runningApplication) {
                        tabs = updatedTabs
                    }
                }
            }
        }

        longRunningTasks.insert(updateTabsTask)
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
}

