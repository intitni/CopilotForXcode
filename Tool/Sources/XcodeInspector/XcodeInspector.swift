import AppKit
import AsyncAlgorithms
import AXExtension
import Combine
import Foundation
import Logger
import Preferences
import SuggestionModel
import Toast

public extension Notification.Name {
    static let accessibilityAPIMalfunctioning = Notification.Name("accessibilityAPIMalfunctioning")
}

public final class XcodeInspector: ObservableObject {
    public static let shared = XcodeInspector()

    private var toast: ToastController { ToastControllerDependencyKey.liveValue }

    private var cancellable = Set<AnyCancellable>()
    private var activeXcodeObservations = Set<Task<Void, Error>>()
    private var appChangeObservations = Set<Task<Void, Never>>()
    private var activeXcodeCancellable = Set<AnyCancellable>()

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
        latestActiveXcode?.realtimeProjectURL ?? activeProjectRootURL
    }

    init() {
        restart()
    }

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

        let appChangeTask = Task { [weak self] in
            guard let self else { return }
            if let activeXcode {
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
                            if let existed = xcodes.first(where: {
                                $0.runningApplication.processIdentifier == app.processIdentifier
                            }) {
                                await MainActor.run {
                                    self.setActiveXcode(existed)
                                }
                            } else {
                                let new = XcodeAppInstanceInspector(runningApplication: app)
                                await MainActor.run {
                                    self.xcodes.append(new)
                                    self.setActiveXcode(new)
                                }
                            }
                        } else {
                            let appInspector = AppInstanceInspector(runningApplication: app)
                            await MainActor.run {
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
                            await MainActor.run {
                                self.xcodes.removeAll {
                                    $0.runningApplication.processIdentifier == processIdentifier
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
                            try await Task.sleep(nanoseconds: 10_000_000_000)
                            Logger.service.debug("""
                            Check for Accessibility Malfunctioning:
                            Source Editor: \({
                                if let editor = self.focusedEditor {
                                    return editor.element.description
                                }
                                return "Not Found"
                            }())
                            Focused Element: \({
                                if let element = self.focusedElement {
                                    return "\(element.description), \(element.identifier), \(element.role)"
                                }
                                return "Not Found"
                            }())

                            Accessibility API Permission: \(
                                AXIsProcessTrusted() ? "Granted" :
                                    "Not Granted"
                            )
                            App: \(
                                self.activeApplication?.runningApplication
                                    .bundleIdentifier ?? ""
                            )
                            Focused Element: \({
                                guard let element = self.activeApplication?.appElement
                                    .focusedElement
                                else {
                                    return "Not Found"
                                }
                                return "\(element.description), \(element.identifier), \(element.role)"
                            }())
                            First Source Editor: \({
                                guard let element = self.activeApplication?.appElement
                                    .firstChild(where: \.isSourceEditor)
                                else {
                                    return "Not Found"
                                }
                                return "\(element.description), \(element.identifier), \(element.role)"
                            }())
                            """)

                            if let editor = self.focusedEditor, !editor.element.isSourceEditor {
                                NSWorkspace.shared.notificationCenter.post(
                                    name: .accessibilityAPIMalfunctioning,
                                    object: "Source Editor Element Corrupted"
                                )
                            } else if let element = self.activeXcode?.appElement.focusedElement {
                                if element.description != self.focusedElement?.description ||
                                    element.identifier != self.focusedElement?.role
                                {
                                    NSWorkspace.shared.notificationCenter.post(
                                        name: .accessibilityAPIMalfunctioning,
                                        object: "Element Inconsistency"
                                    )
                                }
                            }
                        }
                    }
                    
                    group.addTask {
                        let sequence = DistributedNotificationCenter.default()
                            .notifications(named: .init("com.apple.accessibility.api"))
                        for await notification in sequence {
                            if AXIsProcessTrusted() {
                                Logger.service.debug("Accessibility API Permission Granted")
                            } else {
                                Logger.service.debug("Accessibility API Permission Not Granted")
                                NSWorkspace.shared.notificationCenter.post(
                                    name: .accessibilityAPIMalfunctioning,
                                    object: "Accessibility API Permission Check"
                                )
                            }
                        }
                    }
                }
                
                

                group.addTask { [weak self] in // malfunctioning
                    let sequence = NSWorkspace.shared.notificationCenter
                        .notifications(named: .accessibilityAPIMalfunctioning)
                    for await notification in sequence {
                        guard let self else { return }
                        let toast = self.toast
                        toast.toast(
                            content: "Accessibility API malfunction detected: \(notification.object as? String ?? "")",
                            type: .warning
                        )
                        if let activeXcode {
                            toast.toast(content: "Resetting active Xcode", type: .warning)
                            await MainActor.run {
                                self.setActiveXcode(activeXcode)
                            }
                        }
                    }
                }
            }
        }

        appChangeObservations.insert(appChangeTask)
    }

    @MainActor
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

        let setFocusedElement = { [weak self] in
            guard let self else { return }
            focusedElement = xcode.appElement.focusedElement
            Logger.service.debug("Update focused element.")
            if let editorElement = focusedElement, editorElement.isSourceEditor {
                Logger.service.debug("Focused on source editor.")
                focusedEditor = .init(
                    runningApplication: xcode.runningApplication,
                    element: editorElement
                )
            } else if let element = focusedElement,
                      let editorElement = element.firstParent(where: \.isSourceEditor)
            {
                Logger.service.debug("Focused on child of source editor.")
                focusedEditor = .init(
                    runningApplication: xcode.runningApplication,
                    element: editorElement
                )
            } else {
                Logger.service.debug("No source editor found.")
                focusedEditor = nil
            }
        }

        setFocusedElement()
        let focusedElementChanged = Task { @MainActor in
            for await notification in xcode.axNotifications {
                guard notification.kind == .focusedUIElementChanged else { continue }
                Logger.service.debug("Update focused element")
                try Task.checkCancellation()
                setFocusedElement()
            }
        }

        activeXcodeObservations.insert(focusedElementChanged)

        xcode.$completionPanel.receive(on: DispatchQueue.main).sink { [weak self] element in
            self?.completionPanel = element
        }.store(in: &activeXcodeCancellable)

        xcode.$documentURL.receive(on: DispatchQueue.main).sink { [weak self] url in
            self?.activeDocumentURL = url
        }.store(in: &activeXcodeCancellable)

        xcode.$workspaceURL.receive(on: DispatchQueue.main).sink { [weak self] url in
            self?.activeWorkspaceURL = url
        }.store(in: &activeXcodeCancellable)

        xcode.$projectRootURL.receive(on: DispatchQueue.main).sink { [weak self] url in
            self?.activeProjectRootURL = url
        }.store(in: &activeXcodeCancellable)

        xcode.$focusedWindow.receive(on: DispatchQueue.main).sink { [weak self] window in
            self?.focusedWindow = window
        }.store(in: &activeXcodeCancellable)
    }
}

