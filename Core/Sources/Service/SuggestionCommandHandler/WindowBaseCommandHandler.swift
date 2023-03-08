import CopilotModel
import CopilotService
import Environment
import Foundation
import os.log
import SuggestionInjector
import XPCShared

@ServiceActor
struct WindowBaseCommandHandler: SuggestionCommandHandler {
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
            editor: editor
        )

        if let suggestion = filespace.presentingSuggestion {
            presenter.presentSuggestion(
                suggestion,
                lines: editor.lines,
                language: filespace.language,
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
        workspace.selectNextSuggestion(forFileAt: fileURL)

        if let suggestion = filespace.presentingSuggestion {
            presenter.presentSuggestion(
                suggestion,
                lines: editor.lines,
                language: filespace.language,
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
        workspace.selectPreviousSuggestion(forFileAt: fileURL)

        if let suggestion = filespace.presentingSuggestion {
            presenter.presentSuggestion(
                suggestion,
                lines: editor.lines,
                language: filespace.language,
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
        workspace.rejectSuggestion(forFileAt: fileURL, editor: editor)
        presenter.discardSuggestion(fileURL: fileURL)
    }

    func acceptSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        presenter.markAsProcessing(true)
        defer { presenter.markAsProcessing(false) }
        
        do {
            let result = try await CommentBaseCommandHandler().acceptSuggestion(editor: editor)
            Task {
                let fileURL = try await Environment.fetchCurrentFileURL()
                presenter.discardSuggestion(fileURL: fileURL)
            }
            return result
        } catch {
            throw error
        }
    }

    func presentRealtimeSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        // not needed.
        return nil
    }

    func generateRealtimeSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        return try await presentSuggestions(editor: editor)
    }
}
