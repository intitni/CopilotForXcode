import Combine
import Foundation
import Perception
import RunEnvironment
import SuggestionBasic
import SwiftUI
import XcodeInspector

/// A passive tracker that observe the changes of the source editor content.
@Perceptible
final class TextCursorTracker {
    @MainActor
    var cursorPosition: CursorPosition { content.cursorPosition }
    @MainActor
    var currentLine: String {
        if content.cursorPosition.line >= 0, content.cursorPosition.line < content.lines.count {
            content.lines[content.cursorPosition.line]
        } else {
            ""
        }
    }

    @MainActor
    var content: SourceEditor.Content = .init(
        content: "",
        lines: [],
        selections: [],
        cursorPosition: .zero,
        cursorOffset: 0,
        lineAnnotations: []
    )

    @PerceptionIgnored var editorObservationTask: Set<AnyCancellable> = []
    @PerceptionIgnored var eventObservationTask: Task<Void, Never>?

    init() {
        observeAppChange()
    }

    deinit {
        eventObservationTask?.cancel()
    }

    private func observeAppChange() {
        if RunEnvironment.isPreview { return }
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
        if RunEnvironment.isPreview { return }
        eventObservationTask?.cancel()
        let content = editor.getLatestEvaluatedContent()
        Task { @MainActor in
            self.content = content
        }
        eventObservationTask = Task { [weak self] in
            for await event in await editor.axNotifications.notifications() {
                guard let self else { return }
                guard event.kind == .evaluatedContentChanged else { continue }
                let content = editor.getLatestEvaluatedContent()
                Task { @MainActor in
                    self.content = content
                }
            }
        }
    }
}

struct TextCursorTrackerEnvironmentKey: EnvironmentKey {
    static var defaultValue: TextCursorTracker = .init()
}

extension EnvironmentValues {
    var textCursorTracker: TextCursorTracker {
        get { self[TextCursorTrackerEnvironmentKey.self] }
        set { self[TextCursorTrackerEnvironmentKey.self] = newValue }
    }
}

