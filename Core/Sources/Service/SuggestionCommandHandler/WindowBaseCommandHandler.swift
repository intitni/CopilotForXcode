import CopilotModel
import Foundation
import SuggestionInjector
import XPCShared

@ServiceActor
struct WindowBaseCommandHandler: SuggestionCommandHanlder {
    nonisolated init() {}

    func presentSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            try await _presentSuggestions(editor: editor)
        }
        return nil
    }

    private func _presentSuggestions(editor: EditorContent) async throws {
        let fileURL = try await Environment.fetchCurrentFileURL()
        let (workspace, filespace) = try await Workspace
            .fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)

        try Task.checkCancellation()

        let snapshot = Filespace.Snapshot(
            linesHash: editor.lines.hashValue,
            cursorPosition: editor.cursorPosition
        )

        // There is no need to regenerate suggestions for the same editor content.
        guard filespace.suggestionSourceSnapshot != snapshot else { return }

        try await workspace.generateSuggestions(
            forFileAt: fileURL,
            content: editor.content,
            lines: editor.lines,
            cursorPosition: editor.cursorPosition,
            tabSize: editor.tabSize,
            indentSize: editor.indentSize,
            usesTabsForIndentation: editor.usesTabsForIndentation
        )

        if let suggestion = filespace.presentingSuggestion {
            presentSuggestion(suggestion, lines: editor.lines, fileURL: fileURL)
        } else {
            discardSuggestion(fileURL: fileURL)
        }
    }

    func presentNextSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            try await _presentNextSuggestion(editor: editor)
        }
        return nil
    }

    private func _presentNextSuggestion(editor: EditorContent) async throws {
        let fileURL = try await Environment.fetchCurrentFileURL()
        let (workspace, filespace) = try await Workspace
            .fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
        workspace.selectNextSuggestion(
            forFileAt: fileURL,
            content: editor.content,
            lines: editor.lines
        )

        if let suggestion = filespace.presentingSuggestion {
            presentSuggestion(suggestion, lines: editor.lines, fileURL: fileURL)
        } else {
            discardSuggestion(fileURL: fileURL)
        }
    }

    func presentPreviousSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            try await _presentPreviousSuggestion(editor: editor)
        }
        return nil
    }

    private func _presentPreviousSuggestion(editor: EditorContent) async throws {
        let fileURL = try await Environment.fetchCurrentFileURL()
        let (workspace, filespace) = try await Workspace
            .fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
        workspace.selectPreviousSuggestion(
            forFileAt: fileURL,
            content: editor.content,
            lines: editor.lines
        )

        if let suggestion = filespace.presentingSuggestion {
            presentSuggestion(suggestion, lines: editor.lines, fileURL: fileURL)
        } else {
            discardSuggestion(fileURL: fileURL)
        }
    }

    func rejectSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            try await _rejectSuggestion(editor: editor)
        }
        return nil
    }

    private func _rejectSuggestion(editor: EditorContent) async throws {
        let fileURL = try await Environment.fetchCurrentFileURL()
        let (workspace, _) = try await Workspace.fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
        workspace.rejectSuggestion(forFileAt: fileURL)

        discardSuggestion(fileURL: fileURL)
    }

    func acceptSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            let fileURL = try await Environment.fetchCurrentFileURL()
            discardSuggestion(fileURL: fileURL)
        }
        return try await CommentBaseCommandHandler().acceptSuggestion(editor: editor)
    }

    func presentRealtimeSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        // not needed.
        return nil
    }

    func generateRealtimeSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        try await presentSuggestions(editor: editor)
    }

    func presentSuggestion(_ suggestion: CopilotCompletion, lines: [String], fileURL: URL) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionPanelController
            controller.suggestCode(
                suggestion.text,
                startLineIndex: suggestion.position.line,
                fileURL: fileURL
            )
        }
    }

    func discardSuggestion(fileURL: URL) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionPanelController
            controller.discardSuggestion(fileURL: fileURL)
        }
    }
}
