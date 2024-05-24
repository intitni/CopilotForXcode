import Combine
import Foundation
import Perception
import SuggestionModel
import XcodeInspector

@Perceptible
final class CursorPositionTracker {
    @MainActor
    var cursorPosition: CursorPosition = .zero

    @PerceptionIgnored var editorObservationTask: Set<AnyCancellable> = []
    @PerceptionIgnored var eventObservationTask: Task<Void, Never>?

    init() {
        observeAppChange()
    }

    deinit {
        eventObservationTask?.cancel()
    }

    private func observeAppChange() {
        editorObservationTask = []
        Task {
            await XcodeInspector.shared.safe.$focusedEditor.sink { [weak self] editor in
                guard let editor, let self else { return }
                Task { @MainActor in
                    self.observeAXNotifications(editor)
                }
            }.store(in: &editorObservationTask)
        }
    }

    private func observeAXNotifications(_ editor: SourceEditor) {
        eventObservationTask?.cancel()
        let content = editor.getLatestEvaluatedContent()
        Task { @MainActor in
            self.cursorPosition = content.cursorPosition
        }
        eventObservationTask = Task { [weak self] in
            for await event in await editor.axNotifications.notifications() {
                guard let self else { return }
                guard event.kind == .evaluatedContentChanged else { continue }
                let content = editor.getLatestEvaluatedContent()
                Task { @MainActor in
                    self.cursorPosition = content.cursorPosition
                }
            }
        }
    }
}

