import AppKit
import AsyncAlgorithms
import AXExtension
import Combine
import Foundation
import Logger
import Perception
import Preferences
import SuggestionBasic
import SwiftNavigation
import Toast

public extension Notification.Name {
    static let accessibilityAPIMalfunctioning = Notification
        .Name("XcodeInspector.accessibilityAPIMalfunctioning")
    static let activeApplicationDidChange = Notification
        .Name("XcodeInspector.activeApplicationDidChange")
    static let previousActiveApplicationDidChange = Notification
        .Name("XcodeInspector.previousActiveApplicationDidChange")
    static let activeXcodeDidChange = Notification
        .Name("XcodeInspector.activeXcodeDidChange")
    static let latestActiveXcodeDidChange = Notification
        .Name("XcodeInspector.latestActiveXcodeDidChange")
    static let xcodesDidChange = Notification.Name("XcodeInspector.xcodesDidChange")
    static let activeProjectRootURLDidChange = Notification
        .Name("XcodeInspector.activeProjectRootURLDidChange")
    static let activeDocumentURLDidChange = Notification
        .Name("XcodeInspector.activeDocumentURLDidChange")
    static let activeWorkspaceURLDidChange = Notification
        .Name("XcodeInspector.activeWorkspaceURLDidChange")
    static let focusedWindowDidChange = Notification
        .Name("XcodeInspector.focusedWindowDidChange")
    static let focusedEditorDidChange = Notification
        .Name("XcodeInspector.focusedEditorDidChange")
    static let focusedElementDidChange = Notification
        .Name("XcodeInspector.focusedElementDidChange")
    static let completionPanelDidChange = Notification
        .Name("XcodeInspector.completionPanelDidChange")
    static let xcodeWorkspacesDidChange = Notification
        .Name("XcodeInspector.xcodeWorkspacesDidChange")
}

@globalActor
public enum XcodeInspectorActor: GlobalActor {
    public actor Actor {}
    public static let shared = Actor()
}

@XcodeInspectorActor
@Perceptible
public final class XcodeInspector: Sendable {
    public final class PerceptionObserver: Sendable {
        public struct Cancellable {
            let token: ObserveToken
            public func cancel() {
                token.cancel()
            }
        }

        final class Object: NSObject, Sendable {}

        let object = Object()

        @MainActor
        @discardableResult public func observe(
            _ block: @Sendable @escaping @MainActor () -> Void
        ) -> Cancellable {
            let token = object.observe { block() }
            return Cancellable(token: token)
        }
    }

    public nonisolated static func createObserver() -> PerceptionObserver {
        PerceptionObserver()
    }

    public nonisolated static let shared = XcodeInspector()

    private var toast: ToastController { ToastControllerDependencyKey.liveValue }

    @PerceptionIgnored private var activeXcodeObservations = Set<Task<Void, Error>>()
    @PerceptionIgnored private var appChangeObservations = Set<Task<Void, Never>>()

    @MainActor
    public fileprivate(set) var activeApplication: AppInstanceInspector? {
        didSet {
            NotificationCenter.default.post(name: .activeApplicationDidChange, object: nil)
        }
    }

    @MainActor
    public fileprivate(set) var previousActiveApplication: AppInstanceInspector? {
        didSet {
            NotificationCenter.default.post(name: .previousActiveApplicationDidChange, object: nil)
        }
    }

    @MainActor
    public fileprivate(set) var activeXcode: XcodeAppInstanceInspector? {
        didSet {
            NotificationCenter.default.post(name: .activeXcodeDidChange, object: nil)
            NotificationCenter.default.post(name: .focusedWindowDidChange, object: nil)
            NotificationCenter.default.post(name: .activeDocumentURLDidChange, object: self)
            NotificationCenter.default.post(name: .activeWorkspaceURLDidChange, object: self)
            NotificationCenter.default.post(name: .activeProjectRootURLDidChange, object: self)
            NotificationCenter.default.post(name: .completionPanelDidChange, object: self)
            NotificationCenter.default.post(name: .xcodeWorkspacesDidChange, object: self)
        }
    }

    @MainActor
    public fileprivate(set) var latestActiveXcode: XcodeAppInstanceInspector? {
        didSet {
            _nonIsolatedLatestActiveXcode = latestActiveXcode
            NotificationCenter.default.post(name: .latestActiveXcodeDidChange, object: nil)
        }
    }

    @MainActor
    public fileprivate(set) var xcodes: [XcodeAppInstanceInspector] = [] {
        didSet {
            NotificationCenter.default.post(name: .xcodesDidChange, object: nil)
        }
    }

    @MainActor
    public var activeProjectRootURL: URL? {
        (activeXcode ?? latestActiveXcode)?.projectRootURL
    }

    @MainActor
    public var activeDocumentURL: URL? {
        (activeXcode ?? latestActiveXcode)?.documentURL
    }

    @MainActor
    public var activeWorkspaceURL: URL? {
        (activeXcode ?? latestActiveXcode)?.workspaceURL
    }

    @MainActor
    public var focusedWindow: XcodeWindowInspector? {
        (activeXcode ?? latestActiveXcode)?.focusedWindow
    }

    @MainActor
    public var completionPanel: AXUIElement? {
        (activeXcode ?? latestActiveXcode)?.completionPanel
    }

    @MainActor
    public fileprivate(set) var focusedEditor: SourceEditor? {
        didSet {
            NotificationCenter.default.post(name: .focusedEditorDidChange, object: nil)
        }
    }

    @MainActor
    public fileprivate(set) var focusedElement: AXUIElement? {
        didSet {
            NotificationCenter.default.post(name: .focusedElementDidChange, object: nil)
        }
    }

    /// Get the content of the source editor.
    ///
    /// - note: This method is expensive. It needs to convert index based ranges to line based
    /// ranges.
    public func getFocusedEditorContent() async -> EditorInformation? {
        guard let documentURL = realtimeActiveDocumentURL,
              let workspaceURL = realtimeActiveWorkspaceURL,
              let projectURL = realtimeActiveProjectURL
        else { return nil }

        let editorContent = await focusedEditor?.getContent()
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

    @PerceptionIgnored
    private nonisolated(unsafe) var _nonIsolatedLatestActiveXcode: XcodeAppInstanceInspector?

    public nonisolated var realtimeActiveDocumentURL: URL? {
        _nonIsolatedLatestActiveXcode?.realtimeDocumentURL
    }

    public nonisolated var realtimeActiveWorkspaceURL: URL? {
        _nonIsolatedLatestActiveXcode?.realtimeWorkspaceURL
    }

    public nonisolated var realtimeActiveProjectURL: URL? {
        _nonIsolatedLatestActiveXcode?.realtimeProjectURL
    }

    nonisolated init() {
        AXUIElement.setGlobalMessagingTimeout(3)
        Task { await restart() }
    }

    public func restart(cleanUp: Bool = false) async {
        if cleanUp {
            activeXcodeObservations.forEach { $0.cancel() }
            activeXcodeObservations.removeAll()
            await MainActor.run {
                self.activeXcode = nil
                latestActiveXcode = nil
                activeApplication = nil
                focusedEditor = nil
                focusedElement = nil
            }
        }

        let runningApplications = NSWorkspace.shared.runningApplications

        await MainActor.run {
            xcodes = runningApplications
                .filter { $0.isXcode }
                .map(XcodeAppInstanceInspector.init(runningApplication:))
            let activeXcode = xcodes.first(where: \.isActive)
            latestActiveXcode = activeXcode ?? xcodes.first
            activeApplication = activeXcode ?? runningApplications
                .first(where: \.isActive)
                .map(AppInstanceInspector.init(runningApplication:))
            self.activeXcode = activeXcode
        }

        appChangeObservations.forEach { $0.cancel() }
        appChangeObservations.removeAll()

        let appChangeTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            if let activeXcode = await self.activeXcode {
                await setActiveXcode(activeXcode)
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
                            if let existed = await self.xcodes.first(where: {
                                $0.processIdentifier == app.processIdentifier && !$0.isTerminated
                            }) {
                                Task {
                                    await self.setActiveXcode(existed)
                                }
                            } else {
                                let new = XcodeAppInstanceInspector(runningApplication: app)
                                Task { @MainActor in
                                    self.xcodes.append(new)
                                    await self.setActiveXcode(new)
                                }
                            }
                        } else {
                            let appInspector = AppInstanceInspector(runningApplication: app)
                            Task { @MainActor in
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
                            Task { @MainActor in
                                self.xcodes.removeAll {
                                    $0.processIdentifier == processIdentifier || $0.isTerminated
                                }
                                if self.latestActiveXcode?.runningApplication
                                    .processIdentifier == processIdentifier
                                {
                                    self.latestActiveXcode = nil
                                }

                                if let activeXcode = self.xcodes.first(where: \.isActive) {
                                    await self.setActiveXcode(activeXcode)
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
                            Task {
                                await self.checkForAccessibilityMalfunction("Timer")
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

    public func reactivateObservationsToXcode() async {
        if let activeXcode = await activeXcode {
            await setActiveXcode(activeXcode)
            activeXcode.observeAXNotifications()
        }
    }

    private func setActiveXcode(_ xcode: XcodeAppInstanceInspector) async {
        await MainActor.run {
            previousActiveApplication = activeApplication
            activeApplication = xcode
        }
        xcode.refresh()
        for task in activeXcodeObservations { task.cancel() }
        activeXcodeObservations.removeAll()
        await MainActor.run {
            activeXcode = xcode
            latestActiveXcode = xcode
        }

        let setFocusedElement = { [weak self] in
            guard let self else { return }
            await MainActor.run {
                self.focusedElement = xcode.appElement.focusedElement
                if let editorElement = self.focusedElement, editorElement.isSourceEditor {
                    self.focusedEditor = .init(
                        runningApplication: xcode.runningApplication,
                        element: editorElement
                    )
                } else if let element = self.focusedElement,
                          let editorElement = element.firstParent(where: \.isSourceEditor)
                {
                    self.focusedEditor = .init(
                        runningApplication: xcode.runningApplication,
                        element: editorElement
                    )
                } else {
                    self.focusedEditor = nil
                }
            }
        }

        await setFocusedElement()
        let focusedElementChanged = Task {
            for await notification in await xcode.axNotifications.notifications() {
                if notification.kind == .focusedUIElementChanged {
                    try Task.checkCancellation()
                    await setFocusedElement()
                }
            }
        }

        activeXcodeObservations.insert(focusedElementChanged)

        if UserDefaults.shared
            .value(for: \.restartXcodeInspectorIfAccessibilityAPIIsMalfunctioning)
        {
            let malfunctionCheck = Task { [weak self] in
                if #available(macOS 13.0, *) {
                    let notifications = await xcode.axNotifications.notifications().filter {
                        $0.kind == .uiElementDestroyed
                    }.debounce(for: .milliseconds(1000))
                    for await _ in notifications {
                        guard let self else { return }
                        try Task.checkCancellation()
                        await self.checkForAccessibilityMalfunction("Element Destroyed")
                    }
                }
            }

            activeXcodeObservations.insert(malfunctionCheck)

            await checkForAccessibilityMalfunction("Reactivate Xcode")
        }
    }

    private var lastRecoveryFromAccessibilityMalfunctioningTimeStamp = Date()

    private func checkForAccessibilityMalfunction(_ source: String) async {
        guard Date().timeIntervalSince(lastRecoveryFromAccessibilityMalfunctioningTimeStamp) > 5
        else { return }

        if let editor = await focusedEditor, !editor.element.isSourceEditor {
            NotificationCenter.default.post(
                name: .accessibilityAPIMalfunctioning,
                object: "Source Editor Element Corrupted: \(source)"
            )
        } else if let element = await activeXcode?.appElement.focusedElement {
            let focusedElement = await focusedElement
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

    private func recoverFromAccessibilityMalfunctioning(_ source: String?) async {
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
        if let activeXcode = await activeXcode {
            lastRecoveryFromAccessibilityMalfunctioningTimeStamp = Date()
            await setActiveXcode(activeXcode)
            activeXcode.observeAXNotifications()
        }
    }
}

