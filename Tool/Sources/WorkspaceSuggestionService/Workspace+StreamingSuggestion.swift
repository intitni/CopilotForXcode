import Foundation
import SuggestionBasic
import SuggestionProvider
import Workspace
import XPCShared

public extension Workspace {
    /// Streaming variant of ``generateSuggestions(forFileAt:editor:)``.
    ///
    /// The filespace is updated with every partial result and `onPartial` is called right after,
    /// so the caller can refresh the widget while the model is still writing. The loop ends as
    /// soon as the round is over from the user's point of view (accepted, rejected, dismissed or
    /// invalidated by typing), which also cancels the request. Providers that can't stream go
    /// through the blocking path unchanged.
    @WorkspaceActor
    @discardableResult
    func generateSuggestionsStreaming(
        forFileAt fileURL: URL,
        editor: EditorContent,
        onPartial: (CodeSuggestion) -> Void
    ) async throws -> [CodeSuggestion] {
        guard let streamingService = suggestionService as? StreamingSuggestionServiceProvider
        else {
            return try await generateSuggestions(forFileAt: fileURL, editor: editor)
        }

        refreshUpdateTime()

        let filespace = try createFilespaceIfNeeded(fileURL: fileURL)

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

        let content = editor.lines.joined(separator: "")
        let relevantCodeSnippets = SuggestionContextCollector.shared.collectSnippets(
            for: fileURL,
            lines: editor.lines,
            cursorPosition: editor.cursorPosition,
            workspace: self
        )
        let stream = await streamingService.streamSuggestions(
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
                relevantCodeSnippets: relevantCodeSnippets
            ),
            workspaceInfo: .init(workspaceURL: workspaceURL, projectURL: projectRootURL)
        )

        var latest = [CodeSuggestion]()
        var presentedID: String?
        for try await partial in stream {
            if Task.isCancelled { break }
            guard Self.roundIsStillOpen(filespace, snapshot: snapshot, presentedID: presentedID)
            else { break }
            latest = partial
            guard let first = partial.first else { continue }
            filespace.setSuggestions(partial)
            presentedID = first.id
            onPartial(first)
        }
        return latest
    }

    /// False once accept / reject / dismiss / invalidation has reset the round.
    @WorkspaceActor
    private static func roundIsStillOpen(
        _ filespace: Filespace,
        snapshot: FilespaceSuggestionSnapshot,
        presentedID: String?
    ) -> Bool {
        guard filespace.suggestionSourceSnapshot == snapshot else { return false }
        guard let presentedID else { return true }
        return filespace.presentingSuggestion?.id == presentedID
    }
}
