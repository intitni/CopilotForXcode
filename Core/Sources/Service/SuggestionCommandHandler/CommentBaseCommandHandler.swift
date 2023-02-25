import CopilotModel
import Foundation
import SuggestionInjector
import XPCShared

@ServiceActor
struct CommentBaseCommandHandler: SuggestionCommandHanlder {
    nonisolated init() {}

    func presentSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        let fileURL = try await Environment.fetchCurrentFileURL()
        let (workspace, _) = try await Workspace.fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
        try await workspace.generateSuggestions(
            forFileAt: fileURL,
            content: editor.content,
            lines: editor.lines,
            cursorPosition: editor.cursorPosition,
            tabSize: editor.tabSize,
            indentSize: editor.indentSize,
            usesTabsForIndentation: editor.usesTabsForIndentation
        )

        guard let filespace = workspace.filespaces[fileURL] else { return nil }
        let presenter = PresentInCommentSuggestionPresenter()
        return try await presenter.presentSuggestion(
            for: filespace,
            in: workspace,
            originalContent: editor.content,
            lines: editor.lines,
            cursorPosition: editor.cursorPosition
        )
    }

    func presentNextSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        let fileURL = try await Environment.fetchCurrentFileURL()
        let (workspace, _) = try await Workspace.fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
        workspace.selectNextSuggestion(
            forFileAt: fileURL,
            content: editor.content,
            lines: editor.lines
        )

        guard let filespace = workspace.filespaces[fileURL] else { return nil }
        let presenter = PresentInCommentSuggestionPresenter()
        return try await presenter.presentSuggestion(
            for: filespace,
            in: workspace,
            originalContent: editor.content,
            lines: editor.lines,
            cursorPosition: editor.cursorPosition
        )
    }

    func presentPreviousSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        let fileURL = try await Environment.fetchCurrentFileURL()
        let (workspace, _) = try await Workspace.fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
        workspace.selectPreviousSuggestion(
            forFileAt: fileURL,
            content: editor.content,
            lines: editor.lines
        )

        guard let filespace = workspace.filespaces[fileURL] else { return nil }
        let presenter = PresentInCommentSuggestionPresenter()
        return try await presenter.presentSuggestion(
            for: filespace,
            in: workspace,
            originalContent: editor.content,
            lines: editor.lines,
            cursorPosition: editor.cursorPosition
        )
    }

    func rejectSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        let fileURL = try await Environment.fetchCurrentFileURL()
        let (workspace, _) = try await Workspace.fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
        workspace.rejectSuggestion(forFileAt: fileURL)

        guard let filespace = workspace.filespaces[fileURL] else { return nil }
        let presenter = PresentInCommentSuggestionPresenter()
        return try await presenter.discardSuggestion(
            for: filespace,
            in: workspace,
            originalContent: editor.content,
            lines: editor.lines,
            cursorPosition: editor.cursorPosition
        )
    }

    func acceptSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        let fileURL = try await Environment.fetchCurrentFileURL()
        let (workspace, _) = try await Workspace.fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)

        guard let acceptedSuggestion = workspace.acceptSuggestion(forFileAt: fileURL)
        else { return nil }

        let injector = SuggestionInjector()
        var lines = editor.lines
        var cursorPosition = editor.cursorPosition
        var extraInfo = SuggestionInjector.ExtraInfo()
        injector.rejectCurrentSuggestions(
            from: &lines,
            cursorPosition: &cursorPosition,
            extraInfo: &extraInfo
        )
        injector.acceptSuggestion(
            intoContentWithoutSuggestion: &lines,
            cursorPosition: &cursorPosition,
            completion: acceptedSuggestion,
            extraInfo: &extraInfo
        )

        return .init(
            content: String(lines.joined(separator: "")),
            newCursor: cursorPosition,
            modifications: extraInfo.modifications
        )
    }

    func presentRealtimeSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        let fileURL = try await Environment.fetchCurrentFileURL()
        let (workspace, filespace) = try await Workspace
            .fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)

        try Task.checkCancellation()

        let snapshot = Filespace.Snapshot(
            linesHash: editor.lines.hashValue,
            cursorPosition: editor.cursorPosition
        )

        // If the generated suggestions are for this editor content, present it.
        guard filespace.suggestionSourceSnapshot == snapshot else { return nil }

        let presenter = PresentInCommentSuggestionPresenter()
        return try await presenter.presentSuggestion(
            for: filespace,
            in: workspace,
            originalContent: editor.content,
            lines: editor.lines,
            cursorPosition: editor.cursorPosition
        )
    }

    func generateRealtimeSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        let fileURL = try await Environment.fetchCurrentFileURL()
        let (workspace, filespace) = try await Workspace
            .fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)

        try Task.checkCancellation()

        let snapshot = Filespace.Snapshot(
            linesHash: editor.lines.hashValue,
            cursorPosition: editor.cursorPosition
        )

        // There is no need to regenerate suggestions for the same editor content.
        guard filespace.suggestionSourceSnapshot != snapshot else { return nil }

        let suggestions = try await workspace.generateSuggestions(
            forFileAt: fileURL,
            content: editor.content,
            lines: editor.lines,
            cursorPosition: editor.cursorPosition,
            tabSize: editor.tabSize,
            indentSize: editor.indentSize,
            usesTabsForIndentation: editor.usesTabsForIndentation
        )

        try Task.checkCancellation()

        // If there is a suggestion available, call another command to present it.
        guard !suggestions.isEmpty else { return nil }
        try await Environment.triggerAction("Real-time Suggestions")

        return nil
    }
}
