import AppKit
import AsyncAlgorithms
import AXExtension
import Combine
import Foundation
import Logger
import Preferences
import SuggestionBasic
import Toast

public extension Notification.Name {
    static let accessibilityAPIMalfunctioning = Notification.Name("accessibilityAPIMalfunctioning")
}

@globalActor
public enum XcodeInspectorActor: GlobalActor {
    public actor Actor {}
    public static let shared = Actor()
}

#warning("TODO: Consider rewriting it with Swift Observation")
public final class XcodeInspector: ObservableObject {
    public static let shared = XcodeInspector()
    
    @XcodeInspectorActor
    @dynamicMemberLookup
    public class Safe {
        var inspector: XcodeInspector { .shared }
        nonisolated init() {}
        public subscript<T>(dynamicMember member: KeyPath<XcodeInspector, T>) -> T {
            inspector[keyPath: member]
        }
    }

    private var toast: ToastController { ToastControllerDependencyKey.liveValue }

    private var cancellable = Set<AnyCancellable>()
    private var activeXcodeObservations = Set<Task<Void, Error>>()
    private var appChangeObservations = Set<Task<Void, Never>>()
    private var activeXcodeCancellable = Set<AnyCancellable>()
    
    #warning("TODO: Find a good way to make XcodeInspector thread safe!")
    public var safe = Safe()

    @Published public fileprivate(set) var activeApplication: AppInstanceInspector?
    @Published public fileprivate(set) var previousActiveApplication: AppInstanceInspector?
    @Published public fileprivate(set) var activeXcode: XcodeAppInstanceInspector?
    @Published public fileprivate(set) var latestActiveXcode: XcodeAppInstanceInspector?
    @Published public fileprivate(set) var xcodes: [XcodeAppInstanceInspector] = []
    @Published public fileprivate(set) var activeProjectRootURL: URL? = nil
    @Published public fileprivate(set) var activeDocumentURL: URL? = nil
    @Published public fileprivate(set) var activeWorkspaceURL: URL? = nil
    @Published public fileprivate(set) var focusedWindow: XcodeWindowInspector?
    @Published public fileprivate(set) var focusedEditor: SourceEditor?
    @Published public fileprivate(set) var focusedElement: AXUIElement?
    @Published public fileprivate(set) var completionPanel: AXUIElement?

    /// Get the content of the source editor.
    ///
    /// - note: This method is expensive. It needs to convert index based ranges to line based
    /// ranges.
    @XcodeInspectorActor
    public func getFocusedEditorContent() async -> EditorInformation? {
        guard let documentURL = realtimeActiveDocumentURL,
              let workspaceURL = realtimeActiveWorkspaceURL,
              let projectURL = activeProjectRootURL
        else { return nil }

        let editorContent = focusedEditor?.getContent()
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
        latestActiveXcode?.realtimeProjectURL ?? activeProjectRootURL
    }

    init() {
        AXUIElement.setGlobalMessagingTimeout(3)
        Task { @XcodeInspectorActor in
            restart()
        }
    }

    @XcodeInspectorActor
    public func restart(cleanUp: Bool = false) {
        if cleanUp {
            activeXcodeObservations.forEach { $0.cancel() }
            activeXcodeObservations.removeAll()
            activeXcodeCancellable.forEach { $0.cancel() }
            activeXcodeCancellable.removeAll()
            activeXcode = nil
            latestActiveXcode = nil
            activeApplication = nil
            activeProjectRootURL = nil
            activeDocumentURL = nil
            activeWorkspaceURL = nil
            focusedWindow = nil
            focusedEditor = nil
            focusedElement = nil
            completionPanel = nil
        }

        let runningApplications = NSWorkspace.shared.runningApplications
        xcodes = runningApplications
            .filter { $0.isXcode }
            .map(XcodeAppInstanceInspector.init(runningApplication:))
        let activeXcode = xcodes.first(where: \.isActive)
        latestActiveXcode = activeXcode ?? xcodes.first
        activeApplication = activeXcode ?? runningApplications
            .first(where: \.isActive)
            .map(AppInstanceInspector.init(runningApplication:))

        appChangeObservations.forEach { $0.cancel() }
        appChangeObservations.removeAll()

        let appChangeTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            if let activeXcode {
                setActiveXcode(activeXcode)
            }

            await withThrowingTaskGroup(of: Void.self) { [weak self] group in
                group.addTask { [weak self] in // Did activate app
                    let sequence = NSWorkspace.shared.notificationCenter
                        .notifications(named: NSWorkspace.didActivateApplicationNotification)
                    for await notification in sequence {
                        try Task.checkCancellation()
                        guard let self else { return }
                        guard let app = notification
                            .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                        else { continue }
                        if app.isXcode {
                            if let existed = xcodes.first(where: {
                                $0.processIdentifier == app.processIdentifier && !$0.isTerminated
                            }) {
                                Task { @XcodeInspectorActor in
                                    self.setActiveXcode(existed)
                                }
                            } else {
                                let new = XcodeAppInstanceInspector(runningApplication: app)
                                Task { @XcodeInspectorActor in
                                    self.xcodes.append(new)
                                    self.setActiveXcode(new)
                                }
                            }
                        } else {
                            let appInspector = AppInstanceInspector(runningApplication: app)
                            Task { @XcodeInspectorActor in
                                self.previousActiveApplication = self.activeApplication
                                self.activeApplication = appInspector
                            }
                        }
                    }
                }

                group.addTask { [weak self] in // Did terminate app
                    let sequence = NSWorkspace.shared.notificationCenter
                        .notifications(named: NSWorkspace.didTerminateApplicationNotification)
                    for await notification in sequence {
                        try Task.checkCancellation()
                        guard let self else { return }
                        guard let app = notification
                            .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                        else { continue }
                        if app.isXcode {
                            let processIdentifier = app.processIdentifier
                            Task { @XcodeInspectorActor in
                                self.xcodes.removeAll {
                                    $0.processIdentifier == processIdentifier || $0.isTerminated
                                }
                                if self.latestActiveXcode?.runningApplication
                                    .processIdentifier == processIdentifier
                                {
                                    self.latestActiveXcode = nil
                                }

                                if let activeXcode = self.xcodes.first(where: \.isActive) {
                                    self.setActiveXcode(activeXcode)
                                }
                            }
                        }
                    }
                }

                if UserDefaults.shared
                    .value(for: \.restartXcodeInspectorIfAccessibilityAPIIsMalfunctioning)
                {
                    group.addTask { [weak self] in
                        while true {
                            guard let self else { return }
                            if UserDefaults.shared.value(
                                for: \.restartXcodeInspectorIfAccessibilityAPIIsMalfunctioningNoTimer
                            ) {
                                return
                            }

                            try await Task.sleep(nanoseconds: 10_000_000_000)
                            Task { @XcodeInspectorActor in
                                self.checkForAccessibilityMalfunction("Timer")
                            }
                        }
                    }
                }

                group.addTask { [weak self] in // malfunctioning
                    let sequence = NotificationCenter.default
                        .notifications(named: .accessibilityAPIMalfunctioning)
                    for await notification in sequence {
                        try Task.checkCancellation()
                        guard let self else { return }
                        await self
                            .recoverFromAccessibilityMalfunctioning(notification.object as? String)
                    }
                }
            }
        }

        appChangeObservations.insert(appChangeTask)
    }

    public func reactivateObservationsToXcode() {
        Task { @XcodeInspectorActor in
            if let activeXcode {
                setActiveXcode(activeXcode)
                activeXcode.observeAXNotifications()
            }
        }
    }

    @XcodeInspectorActor
    private func setActiveXcode(_ xcode: XcodeAppInstanceInspector) {
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

        let setFocusedElement = { @XcodeInspectorActor [weak self] in
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
        let focusedElementChanged = Task { @XcodeInspectorActor in
            for await notification in await xcode.axNotifications.notifications() {
                if notification.kind == .focusedUIElementChanged {
                    try Task.checkCancellation()
                    setFocusedElement()
                }
            }
        }

        activeXcodeObservations.insert(focusedElementChanged)

        if UserDefaults.shared
            .value(for: \.restartXcodeInspectorIfAccessibilityAPIIsMalfunctioning)
        {
            let malfunctionCheck = Task { @XcodeInspectorActor [weak self] in
                if #available(macOS 13.0, *) {
                    let notifications = await xcode.axNotifications.notifications().filter {
                        $0.kind == .uiElementDestroyed
                    }.debounce(for: .milliseconds(1000))
                    for await _ in notifications {
                        guard let self else { return }
                        try Task.checkCancellation()
                        self.checkForAccessibilityMalfunction("Element Destroyed")
                    }
                }
            }

            activeXcodeObservations.insert(malfunctionCheck)

            checkForAccessibilityMalfunction("Reactivate Xcode")
        }

        xcode.$completionPanel.sink { [weak self] element in
            Task { @XcodeInspectorActor in self?.completionPanel = element }
        }.store(in: &activeXcodeCancellable)

        xcode.$documentURL.sink { [weak self] url in
            Task { @XcodeInspectorActor in self?.activeDocumentURL = url }
        }.store(in: &activeXcodeCancellable)

        xcode.$workspaceURL.sink { [weak self] url in
            Task { @XcodeInspectorActor in self?.activeWorkspaceURL = url }
        }.store(in: &activeXcodeCancellable)

        xcode.$projectRootURL.sink { [weak self] url in
            Task { @XcodeInspectorActor in self?.activeProjectRootURL = url }
        }.store(in: &activeXcodeCancellable)

        xcode.$focusedWindow.sink { [weak self] window in
            Task { @XcodeInspectorActor in self?.focusedWindow = window }
        }.store(in: &activeXcodeCancellable)
    }

    private var lastRecoveryFromAccessibilityMalfunctioningTimeStamp = Date()

    @XcodeInspectorActor
    private func checkForAccessibilityMalfunction(_ source: String) {
        guard Date().timeIntervalSince(lastRecoveryFromAccessibilityMalfunctioningTimeStamp) > 5
        else { return }

        if let editor = focusedEditor, !editor.element.isSourceEditor {
            NotificationCenter.default.post(
                name: .accessibilityAPIMalfunctioning,
                object: "Source Editor Element Corrupted: \(source)"
            )
        } else if let element = activeXcode?.appElement.focusedElement {
            if element.description != focusedElement?.description ||
                element.role != focusedElement?.role
            {
                NotificationCenter.default.post(
                    name: .accessibilityAPIMalfunctioning,
                    object: "Element Inconsistency: \(source)"
                )
            }
        }
    }

    @XcodeInspectorActor
    private func recoverFromAccessibilityMalfunctioning(_ source: String?) {
        let message = """
        Accessibility API malfunction detected: \
        \(source ?? "").
        Resetting active Xcode.
        """

        if UserDefaults.shared.value(for: \.toastForTheReasonWhyXcodeInspectorNeedsToBeRestarted) {
            toast.toast(content: message, type: .warning)
        } else {
            Logger.service.info(message)
        }
        if let activeXcode {
            lastRecoveryFromAccessibilityMalfunctioningTimeStamp = Date()
            setActiveXcode(activeXcode)
            activeXcode.observeAXNotifications()
        }
    }
}

