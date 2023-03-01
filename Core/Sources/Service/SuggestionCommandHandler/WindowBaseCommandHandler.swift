import CopilotModel
import Environment
import Foundation
import os.log
import SuggestionInjector
import XPCShared

@ServiceActor
struct WindowBaseCommandHandler: SuggestionCommandHanlder {
    nonisolated init() {}

    let presenter = PresentInWindowSuggestionPresenter()

    func presentSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            do {
                try await _presentSuggestions(editor: editor)
            } catch {
                os_log(.error, "%@", error.localizedDescription)
            }
        }
        return nil
    }

    private func _presentSuggestions(editor: EditorContent) async throws {
        presenter.markAsProcessing(true)
        defer {
            presenter.markAsProcessing(false)
            Task {
                await GraphicalUserInterfaceController.shared
                    .realtimeSuggestionIndicatorController
                    .endPrefetchAnimation()
            }
        }
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
            presenter.presentSuggestion(
                suggestion,
                lines: editor.lines,
                fileURL: fileURL,
                currentSuggestionIndex: filespace.suggestionIndex,
                suggestionCount: filespace.suggestions.count
            )
        } else {
            presenter.discardSuggestion(fileURL: fileURL)
        }
    }

    func presentNextSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            try await _presentNextSuggestion(editor: editor)
        }
        return nil
    }

    private func _presentNextSuggestion(editor: EditorContent) async throws {
        presenter.markAsProcessing(true)
        defer { presenter.markAsProcessing(false) }
        let fileURL = try await Environment.fetchCurrentFileURL()
        let (workspace, filespace) = try await Workspace
            .fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
        workspace.selectNextSuggestion(
            forFileAt: fileURL,
            content: editor.content,
            lines: editor.lines
        )

        if let suggestion = filespace.presentingSuggestion {
            presenter.presentSuggestion(
                suggestion,
                lines: editor.lines,
                fileURL: fileURL,
                currentSuggestionIndex: filespace.suggestionIndex,
                suggestionCount: filespace.suggestions.count
            )
        } else {
            presenter.discardSuggestion(fileURL: fileURL)
        }
    }

    func presentPreviousSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            try await _presentPreviousSuggestion(editor: editor)
        }
        return nil
    }

    private func _presentPreviousSuggestion(editor: EditorContent) async throws {
        presenter.markAsProcessing(true)
        defer { presenter.markAsProcessing(false) }
        let fileURL = try await Environment.fetchCurrentFileURL()
        let (workspace, filespace) = try await Workspace
            .fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
        workspace.selectPreviousSuggestion(
            forFileAt: fileURL,
            content: editor.content,
            lines: editor.lines
        )

        if let suggestion = filespace.presentingSuggestion {
            presenter.presentSuggestion(
                suggestion,
                lines: editor.lines,
                fileURL: fileURL,
                currentSuggestionIndex: filespace.suggestionIndex,
                suggestionCount: filespace.suggestions.count
            )
        } else {
            presenter.discardSuggestion(fileURL: fileURL)
        }
    }

    func rejectSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            try await _rejectSuggestion(editor: editor)
        }
        return nil
    }

    private func _rejectSuggestion(editor: EditorContent) async throws {
        presenter.markAsProcessing(true)
        defer { presenter.markAsProcessing(false) }
        let fileURL = try await Environment.fetchCurrentFileURL()
        let (workspace, _) = try await Workspace.fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
        workspace.rejectSuggestion(forFileAt: fileURL)
        presenter.discardSuggestion(fileURL: fileURL)
    }

    func acceptSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        presenter.markAsProcessing(true)
        defer { presenter.markAsProcessing(false) }
        Task {
            let fileURL = try await Environment.fetchCurrentFileURL()
            presenter.discardSuggestion(fileURL: fileURL)
        }
        return try await CommentBaseCommandHandler().acceptSuggestion(editor: editor)
    }

    func presentRealtimeSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        // not needed.
        return nil
    }

    func generateRealtimeSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        await GraphicalUserInterfaceController.shared.realtimeSuggestionIndicatorController
            .triggerPrefetchAnimation()
        return try await presentSuggestions(editor: editor)
    }
}
