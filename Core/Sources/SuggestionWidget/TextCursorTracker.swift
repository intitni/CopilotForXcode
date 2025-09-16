import Foundation
import Perception
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

    @PerceptionIgnored var eventObservationTask: Task<Void, Error>?

    init() {
        observeAppChange()
    }

    deinit {
        eventObservationTask?.cancel()
    }

    var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private func observeAppChange() {
        if isPreview { return }
        Task { [weak self] in
            let notifications = NotificationCenter.default
                .notifications(named: .focusedEditorDidChange)
            for await _ in notifications {
                guard let self else { return }
                guard let editor = await XcodeInspector.shared.focusedEditor else { continue }
                await self.observeAXNotifications(editor)
            }
        }
    }

    private func observeAXNotifications(_ editor: SourceEditor) async {
        if isPreview { return }
        eventObservationTask?.cancel()
        let content = editor.getLatestEvaluatedContent()
        await MainActor.run {
            self.content = content
        }
        eventObservationTask = Task { [weak self] in
            for await event in await editor.axNotifications.notifications() {
                try Task.checkCancellation()
                guard let self else { return }
                guard event.kind == .evaluatedContentChanged else { continue }
                let content = editor.getLatestEvaluatedContent()
                await MainActor.run {
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

