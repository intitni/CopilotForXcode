import Foundation
import SuggestionBasic
import SuggestionProvider
import Workspace
import XPCShared

public extension Workspace {
    var suggestionPlugin: SuggestionServiceWorkspacePlugin? {
        plugin(for: SuggestionServiceWorkspacePlugin.self)
    }

    var suggestionService: SuggestionServiceProvider? {
        suggestionPlugin?.suggestionService
    }

    var isSuggestionFeatureEnabled: Bool {
        suggestionPlugin?.isSuggestionFeatureEnabled ?? false
    }

    struct SuggestionFeatureDisabledError: Error, LocalizedError {
        public var errorDescription: String? {
            "Suggestion feature is disabled for this project."
        }
    }
}

public extension Workspace {
    @WorkspaceActor
    @discardableResult
    func generateSuggestions(
        forFileAt fileURL: URL,
        editor: EditorContent
    ) async throws -> [CodeSuggestion] {
        refreshUpdateTime()

        let filespace = createFilespaceIfNeeded(fileURL: fileURL)

        guard !(await filespace.isGitIgnored) else { return [] }

        if !editor.uti.isEmpty {
            filespace.codeMetadata.uti = editor.uti
            filespace.codeMetadata.tabSize = editor.tabSize
            filespace.codeMetadata.indentSize = editor.indentSize
            filespace.codeMetadata.usesTabsForIndentation = editor.usesTabsForIndentation
        }

        filespace.codeMetadata.guessLineEnding(from: editor.lines.first)

        let snapshot = FilespaceSuggestionSnapshot(
            lines: editor.lines,
            cursorPosition: editor.cursorPosition
        )

        filespace.suggestionSourceSnapshot = snapshot

        guard let suggestionService else { throw SuggestionFeatureDisabledError() }
        let content = editor.lines.joined(separator: "")
        let completions = try await suggestionService.getSuggestions(
            .init(
                fileURL: fileURL,
                relativePath: fileURL.path.replacingOccurrences(of: projectRootURL.path, with: ""),
                content: content,
                originalContent: content,
                lines: editor.lines,
                cursorPosition: editor.cursorPosition,
                cursorOffset: editor.cursorOffset,
                tabSize: editor.tabSize,
                indentSize: editor.indentSize,
                usesTabsForIndentation: editor.usesTabsForIndentation,
                relevantCodeSnippets: []
            ),
            workspaceInfo: .init(workspaceURL: workspaceURL, projectURL: projectRootURL)
        )

        filespace.setSuggestions(completions)

        return completions
    }

    @WorkspaceActor
    func selectNextSuggestion(forFileAt fileURL: URL) {
        refreshUpdateTime()
        guard let filespace = filespaces[fileURL],
              filespace.suggestions.count > 1
        else { return }
        filespace.nextSuggestion()
    }

    @WorkspaceActor
    func selectPreviousSuggestion(forFileAt fileURL: URL) {
        refreshUpdateTime()
        guard let filespace = filespaces[fileURL],
              filespace.suggestions.count > 1
        else { return }
        filespace.previousSuggestion()
    }

    @WorkspaceActor
    func rejectSuggestion(forFileAt fileURL: URL, editor: EditorContent?) {
        refreshUpdateTime()

        if let editor, !editor.uti.isEmpty {
            filespaces[fileURL]?.codeMetadata.uti = editor.uti
            filespaces[fileURL]?.codeMetadata.tabSize = editor.tabSize
            filespaces[fileURL]?.codeMetadata.indentSize = editor.indentSize
            filespaces[fileURL]?.codeMetadata.usesTabsForIndentation = editor.usesTabsForIndentation
        }

        Task {
            await suggestionService?.notifyRejected(
                filespaces[fileURL]?.suggestions ?? [],
                workspaceInfo: .init(
                    workspaceURL: workspaceURL,
                    projectURL: projectRootURL
                )
            )
        }
        filespaces[fileURL]?.reset()
    }

    @WorkspaceActor
    func acceptSuggestion(forFileAt fileURL: URL, editor: EditorContent?) -> CodeSuggestion? {
        refreshUpdateTime()
        guard let filespace = filespaces[fileURL],
              !filespace.suggestions.isEmpty,
              filespace.suggestionIndex >= 0,
              filespace.suggestionIndex < filespace.suggestions.endIndex
        else { return nil }

        if let editor, !editor.uti.isEmpty {
            filespaces[fileURL]?.codeMetadata.uti = editor.uti
            filespaces[fileURL]?.codeMetadata.tabSize = editor.tabSize
            filespaces[fileURL]?.codeMetadata.indentSize = editor.indentSize
            filespaces[fileURL]?.codeMetadata.usesTabsForIndentation = editor.usesTabsForIndentation
        }

        var allSuggestions = filespace.suggestions
        let suggestion = allSuggestions.remove(at: filespace.suggestionIndex)

        Task {
            await suggestionService?.notifyAccepted(
                suggestion,
                workspaceInfo: .init(
                    workspaceURL: workspaceURL,
                    projectURL: projectRootURL
                )
            )
        }

        filespaces[fileURL]?.reset()
        filespaces[fileURL]?.resetSnapshot()

        return suggestion
    }
}

