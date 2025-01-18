import ActiveApplicationMonitor
import AppKit
import AsyncAlgorithms
import AXExtension
import Combine
import DebounceFunction
import Foundation
import Logger
import Preferences
import QuartzCore
import Workspace
import XcodeInspector

public actor RealtimeSuggestionController {
    private var cancellable: Set<AnyCancellable> = []
    private var inflightPrefetchTask: Task<Void, Error>?
    private var editorObservationTask: Task<Void, Error>?
    private var sourceEditor: SourceEditor?
    private let throttledEventTrigger = ThrottleRunner(duration: 0.2)
    private let throttledCleaner = ThrottleRunner(duration: 0.1)

    deinit {
        cancellable.forEach { $0.cancel() }
        inflightPrefetchTask?.cancel()
        editorObservationTask?.cancel()
    }

    nonisolated
    func start() {
        Task { await observeXcodeChange() }
    }

    private func observeXcodeChange() {
        cancellable.forEach { $0.cancel() }

        XcodeInspector.shared.$focusedEditor
            .sink { [weak self] editor in
                guard let self else { return }
                Task {
                    guard let editor else { return }
                    await self.handleFocusElementChange(editor)
                }
            }.store(in: &cancellable)
    }

    private func handleFocusElementChange(_ sourceEditor: SourceEditor) {
        self.sourceEditor = sourceEditor

        let notificationsFromEditor = sourceEditor.axNotifications

        editorObservationTask?.cancel()
        editorObservationTask = nil

        editorObservationTask = Task { [weak self] in
            if let fileURL = await XcodeInspector.shared.safe.realtimeActiveDocumentURL {
                await PseudoCommandHandler().invalidateRealtimeSuggestionsIfNeeded(
                    fileURL: fileURL,
                    sourceEditor: sourceEditor
                )
            }

            let valueChange = await notificationsFromEditor.notifications()
                .filter { $0.kind == .valueChanged }
            let selectedTextChanged = await notificationsFromEditor.notifications()
                .filter { $0.kind == .selectedTextChanged }

            await withTaskGroup(of: Void.self) { [weak self] group in
                group.addTask { [weak self] in
                    let handler = { [weak self] in
                        guard let self else { return }
                        await cancelInFlightTasks()
                        await self.triggerPrefetchDebounced()
                        await self.notifyEditingFileChange(editor: sourceEditor.element)
                    }

                    for await _ in valueChange {
                        guard let self else { return }
                        if Task.isCancelled { return }
                        await self.throttledEventTrigger.throttle {
                            await handler()
                        }
                    }
                }
                group.addTask {
                    let handler = {
                        guard let fileURL = await XcodeInspector.shared.safe.activeDocumentURL
                        else { return }
                        await PseudoCommandHandler().invalidateRealtimeSuggestionsIfNeeded(
                            fileURL: fileURL,
                            sourceEditor: sourceEditor
                        )
                    }

                    for await _ in selectedTextChanged {
                        guard let self else { return }
                        if Task.isCancelled { return }
                        await self.throttledCleaner.throttle {
                            await handler()
                        }
                    }
                }

                await group.waitForAll()
            }
        }

        Task { @WorkspaceActor in // Get cache ready for real-time suggestions.
            guard UserDefaults.shared.value(for: \.preCacheOnFileOpen) else { return }
            guard let fileURL = await XcodeInspector.shared.safe.realtimeActiveDocumentURL
            else { return }
            let (_, filespace) = try await Service.shared.workspacePool
                .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)

            if filespace.codeMetadata.uti == nil {
                Logger.service.info("Generate cache for file.")
                // avoid the command get called twice
                filespace.codeMetadata.uti = ""
                do {
                    try await XcodeInspector.shared.safe.latestActiveXcode?
                        .triggerCopilotCommand(name: "Prepare for Real-time Suggestions")
                } catch {
                    if filespace.codeMetadata.uti?.isEmpty ?? true {
                        filespace.codeMetadata.uti = nil
                    }
                }
            }
        }
    }
}

extension RealtimeSuggestionController {
    func triggerPrefetchDebounced(force: Bool = false) {
        inflightPrefetchTask?.cancel()
        inflightPrefetchTask = Task(priority: .utility) { @WorkspaceActor in
            try? await Task.sleep(nanoseconds: UInt64(
                max(UserDefaults.shared.value(for: \.realtimeSuggestionDebounce), 0.15)
                    * 1_000_000_000
            ))

            if Task.isCancelled { return }

            guard UserDefaults.shared.value(for: \.realtimeSuggestionToggle)
            else { return }

            if UserDefaults.shared.value(for: \.disableSuggestionFeatureGlobally),
               let fileURL = await XcodeInspector.shared.safe.activeDocumentURL,
               let (workspace, _) = try? await Service.shared.workspacePool
               .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
            {
                let isEnabled = workspace.isSuggestionFeatureEnabled
                if !isEnabled { return }
            }
            if Task.isCancelled { return }

            // So the editor won't be blocked (after information are cached)!
            await PseudoCommandHandler().generateRealtimeSuggestions(sourceEditor: sourceEditor)
        }
    }

    func cancelInFlightTasks(excluding: Task<Void, Never>? = nil) async {
        inflightPrefetchTask?.cancel()
        let workspaces = await Service.shared.workspacePool.workspaces
        // cancel in-flight tasks
        await withTaskGroup(of: Void.self) { group in
            for (_, workspace) in workspaces {
                group.addTask {
                    await workspace.cancelInFlightRealtimeSuggestionRequests()
                }
            }
        }
    }

    func notifyEditingFileChange(editor: AXUIElement) async {
        guard let fileURL = await XcodeInspector.shared.safe.activeDocumentURL,
              let (workspace, _) = try? await Service.shared.workspacePool
              .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
        else { return }
        await workspace.didUpdateFilespace(fileURL: fileURL, content: editor.value)
    }
}

