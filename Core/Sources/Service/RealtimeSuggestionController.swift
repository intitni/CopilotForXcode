import ActiveApplicationMonitor
import AppKit
import AsyncAlgorithms
import AXExtension
import AXNotificationStream
import Environment
import Foundation
import Logger
import Preferences
import QuartzCore
import Workspace
import XcodeInspector

public actor RealtimeSuggestionController {
    private var task: Task<Void, Error>?
    private var inflightPrefetchTask: Task<Void, Error>?
    private var windowChangeObservationTask: Task<Void, Error>?
    private var activeApplicationMonitorTask: Task<Void, Error>?
    private var editorObservationTask: Task<Void, Error>?
    private var focusedUIElement: AXUIElement?
    private var sourceEditor: SourceEditor?

    init() {}

    nonisolated
    func start() {
        Task { [weak self] in
            if let app = ActiveApplicationMonitor.shared.activeXcode {
                await self?.handleXcodeChanged(app)
            }
            var previousApp = ActiveApplicationMonitor.shared.activeXcode
            for await app in ActiveApplicationMonitor.shared.createStream() {
                guard let self else { return }
                try Task.checkCancellation()
                defer { previousApp = app }

                if let app = ActiveApplicationMonitor.shared.activeXcode, app != previousApp {
                    await self.handleXcodeChanged(app)
                }
            }
        }
    }

    private func handleXcodeChanged(_ app: NSRunningApplication) {
        windowChangeObservationTask?.cancel()
        windowChangeObservationTask = nil
        observeXcodeWindowChangeIfNeeded(app)
    }

    private func observeXcodeWindowChangeIfNeeded(_ app: NSRunningApplication) {
        guard windowChangeObservationTask == nil else { return }
        handleFocusElementChange()
        windowChangeObservationTask = Task { [weak self] in
            let notifications = AXNotificationStream(
                app: app,
                notificationNames: kAXFocusedUIElementChangedNotification,
                kAXMainWindowChangedNotification
            )
            for await _ in notifications {
                guard let self else { return }
                try Task.checkCancellation()
                await self.handleFocusElementChange()
            }
        }
    }

    private func handleFocusElementChange() {
        guard let activeXcode = ActiveApplicationMonitor.shared.activeXcode else { return }
        let application = AXUIElementCreateApplication(activeXcode.processIdentifier)
        guard let focusElement = application.focusedElement else { return }
        let focusElementType = focusElement.description
        focusedUIElement = focusElement

        Task { // Notify suggestion service for open file.
            try await Task.sleep(nanoseconds: 500_000_000)
            let fileURL = try await Environment.fetchCurrentFileURL()
            _ = try await Service.shared.workspacePool
                .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
        }

        guard focusElementType == "Source Editor" else { return }
        sourceEditor = SourceEditor(runningApplication: activeXcode, element: focusElement)

        editorObservationTask?.cancel()
        editorObservationTask = nil

        editorObservationTask = Task { [weak self] in
            let fileURL = try await Environment.fetchCurrentFileURL()
            if let sourceEditor = await self?.sourceEditor {
                await PseudoCommandHandler().invalidateRealtimeSuggestionsIfNeeded(
                    fileURL: fileURL,
                    sourceEditor: sourceEditor
                )
            }

            let notificationsFromEditor = AXNotificationStream(
                app: activeXcode,
                element: focusElement,
                notificationNames: kAXValueChangedNotification, kAXSelectedTextChangedNotification
            )

            for await notification in notificationsFromEditor {
                guard let self else { return }
                try Task.checkCancellation()

                switch notification.name {
                case kAXValueChangedNotification:
                    await cancelInFlightTasks()
                    await self.triggerPrefetchDebounced()
                    await self.notifyEditingFileChange(editor: focusElement)
                case kAXSelectedTextChangedNotification:
                    guard let sourceEditor = await sourceEditor,
                          let fileURL = XcodeInspector.shared.activeDocumentURL
                    else { continue }
                    await PseudoCommandHandler().invalidateRealtimeSuggestionsIfNeeded(
                        fileURL: fileURL,
                        sourceEditor: sourceEditor
                    )
                default:
                    continue
                }
            }
        }

        Task { @WorkspaceActor in // Get cache ready for real-time suggestions.
            guard UserDefaults.shared.value(for: \.preCacheOnFileOpen) else { return }
            let fileURL = try await Environment.fetchCurrentFileURL()
            let (_, filespace) = try await Service.shared.workspacePool
                .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)

            if filespace.codeMetadata.uti == nil {
                Logger.service.info("Generate cache for file.")
                // avoid the command get called twice
                filespace.codeMetadata.uti = ""
                do {
                    try await Environment.triggerAction("Real-time Suggestions")
                } catch {
                    if filespace.codeMetadata.uti?.isEmpty ?? true {
                        filespace.codeMetadata.uti = nil
                    }
                }
            }
        }
    }

    func triggerPrefetchDebounced(force: Bool = false) {
        inflightPrefetchTask = Task { @WorkspaceActor in
            try? await Task.sleep(nanoseconds: UInt64((
                UserDefaults.shared.value(for: \.realtimeSuggestionDebounce)
            ) * 1_000_000_000))

            guard UserDefaults.shared.value(for: \.realtimeSuggestionToggle)
            else { return }

            if UserDefaults.shared.value(for: \.disableSuggestionFeatureGlobally),
               let fileURL = try? await Environment.fetchCurrentFileURL(),
               let (workspace, _) = try? await Service.shared.workspacePool
               .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
            {
                let isEnabled = workspace.isSuggestionFeatureEnabled
                if !isEnabled { return }
            }
            if Task.isCancelled { return }

//            Logger.service.info("Prefetch suggestions.")

            // So the editor won't be blocked (after information are cached)!
            await PseudoCommandHandler().generateRealtimeSuggestions(sourceEditor: sourceEditor)
        }
    }

    func cancelInFlightTasks(excluding: Task<Void, Never>? = nil) async {
        inflightPrefetchTask?.cancel()

        // cancel in-flight tasks
        await withTaskGroup(of: Void.self) { group in
            for (_, workspace) in Service.shared.workspacePool.workspaces {
                group.addTask {
                    await workspace.cancelInFlightRealtimeSuggestionRequests()
                }
            }
        }
    }

    /// This method will still return true if the completion panel is hidden by esc.
    /// Looks like the Xcode will keep the panel around until content is changed,
    /// not sure how to observe that it's hidden.
    func isCompletionPanelPresenting() -> Bool {
        guard let activeXcode = ActiveApplicationMonitor.shared.activeXcode else { return false }
        let application = AXUIElementCreateApplication(activeXcode.processIdentifier)
        return application.focusedWindow?.child(identifier: "_XC_COMPLETION_TABLE_") != nil
    }

    func notifyEditingFileChange(editor: AXUIElement) async {
        guard let fileURL = try? await Environment.fetchCurrentFileURL(),
              let (workspace, _) = try? await Service.shared.workspacePool
              .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
        else { return }
        await workspace.didUpdateFilespace(fileURL: fileURL, content: editor.value)
    }
}

