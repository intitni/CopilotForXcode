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
        latestActiveXcode?.realtimeProjectURL ?? activeProjectRootURL
    }

    public func restart() {
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
        xcodes = []
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

