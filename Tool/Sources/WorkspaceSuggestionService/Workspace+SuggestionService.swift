import enum CopilotForXcodeKit.SuggestionServiceError
import struct CopilotForXcodeKit.WorkspaceInfo
import Foundation
import SuggestionBasic
import SuggestionProvider
import Workspace
import XPCShared

public protocol SuggestionServiceType {
    func getSuggestions(
        _ request: SuggestionRequest,
        workspaceInfo: CopilotForXcodeKit.WorkspaceInfo
    ) async -> AsyncThrowingStream<[CodeSuggestion], Error>
    func notifyAccepted(
        _ suggestion: CodeSuggestion,
        workspaceInfo: CopilotForXcodeKit.WorkspaceInfo
    ) async
    func notifyRejected(
        _ suggestions: [CodeSuggestion],
        workspaceInfo: CopilotForXcodeKit.WorkspaceInfo
    ) async
    func cancelRequest(workspaceInfo: CopilotForXcodeKit.WorkspaceInfo) async

    var configuration: SuggestionServiceConfiguration { get async }
}

public extension Workspace {
    var suggestionPlugin: SuggestionServiceWorkspacePlugin? {
        plugin(for: SuggestionServiceWorkspacePlugin.self)
    }

    var suggestionService: SuggestionServiceType? {
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

public enum GenerateSuggestionCheck: CaseIterable {
    case skipIfGitIgnored
    case skipIfHasValidSuggestions
    case skipIfSnapshotIsSame
}

public struct GenerateSuggestionSkipError: Error, LocalizedError {
    var reason: GenerateSuggestionCheck
    public var errorDescription: String? {
        "Generate suggestion skipped. Check: \(reason)"
    }
}

public extension Workspace {
    @WorkspaceActor
    @discardableResult
    func generateSuggestions(
        forFileAt fileURL: URL,
        editor: EditorContent,
        checks: Set<GenerateSuggestionCheck> = Set(GenerateSuggestionCheck.allCases)
    ) async throws -> [CodeSuggestion] {
        refreshUpdateTime()

        let filespace = try createFilespaceIfNeeded(fileURL: fileURL)
        filespace.suggestionManager?.updateCursorPosition(editor.cursorPosition)

        if checks.contains(.skipIfGitIgnored),
           await filespace.isGitIgnored
        {
            throw GenerateSuggestionSkipError(reason: .skipIfGitIgnored)
        }

        if !editor.uti.isEmpty {
            filespace.codeMetadata.uti = editor.uti
            filespace.codeMetadata.tabSize = editor.tabSize
            filespace.codeMetadata.indentSize = editor.indentSize
            filespace.codeMetadata.usesTabsForIndentation = editor.usesTabsForIndentation
        }

        filespace.codeMetadata.guessLineEnding(from: editor.lines.first)

        if checks.contains(.skipIfHasValidSuggestions),
           filespace.activeCodeSuggestion != nil
        {
            // Check if the current suggestion is still valid.
            if filespace.validateSuggestions(
                lines: editor.lines,
                cursorPosition: editor.cursorPosition
            ) {
                throw GenerateSuggestionSkipError(reason: .skipIfHasValidSuggestions)
            }
        }

        let snapshot = FilespaceSuggestionSnapshot(
            lines: editor.lines,
            cursorPosition: editor.cursorPosition
        )

        if checks.contains(.skipIfSnapshotIsSame),
           filespace.suggestionManager?.defaultSuggestionProvider
           .suggestionSourceSnapshot == snapshot
        {
            throw GenerateSuggestionSkipError(reason: .skipIfSnapshotIsSame)
        }

        filespace.suggestionManager?.defaultSuggestionProvider.suggestionSourceSnapshot = snapshot

        guard let suggestionService else { throw SuggestionFeatureDisabledError() }
        let content = editor.lines.joined(separator: "")
        let stream = await suggestionService.getSuggestions(
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

        var allCompletions: [CodeSuggestion] = []
        for try await completions in stream {
            try Task.checkCancellation()
            allCompletions.append(contentsOf: completions)
            filespace.suggestionManager?.receiveSuggestions(completions)
        }

        return allCompletions
    }

    @WorkspaceActor
    func selectNextSuggestion(forFileAt fileURL: URL, groupIndex: Int? = nil) {
        refreshUpdateTime()
        guard let filespace = filespaces[fileURL] else { return }
        filespace.selectNextSuggestion(inGroup: groupIndex)
    }

    @WorkspaceActor
    func selectPreviousSuggestion(forFileAt fileURL: URL, groupIndex: Int? = nil) {
        refreshUpdateTime()
        guard let filespace = filespaces[fileURL] else { return }
        filespace.selectPreviousSuggestion(inGroup: groupIndex)
    }

    @WorkspaceActor
    func selectNextSuggestionGroup(forFileAt fileURL: URL) {
        refreshUpdateTime()
        guard let filespace = filespaces[fileURL] else { return }
        filespace.selectNextSuggestionGroup()
    }

    @WorkspaceActor
    func selectPreviousSuggestionGroup(forFileAt fileURL: URL) {
        refreshUpdateTime()
        guard let filespace = filespaces[fileURL] else { return }
        filespace.selectPreviousSuggestionGroup()
    }

    @WorkspaceActor
    func rejectSuggestion(forFileAt fileURL: URL, editor: EditorContent?, groupIndex: Int? = nil) {
        refreshUpdateTime()
        guard let filespace = filespaces[fileURL] else { return }

        if let editor, !editor.uti.isEmpty {
            filespace.suggestionManager?.updateCursorPosition(editor.cursorPosition)
            filespaces[fileURL]?.codeMetadata.uti = editor.uti
            filespaces[fileURL]?.codeMetadata.tabSize = editor.tabSize
            filespaces[fileURL]?.codeMetadata.indentSize = editor.indentSize
            filespaces[fileURL]?.codeMetadata.usesTabsForIndentation = editor.usesTabsForIndentation
        }

        let rejectedSuggestions = filespace.rejectSuggestion(inGroup: groupIndex)

        Task {
            await suggestionService?.notifyRejected(
                rejectedSuggestions,
                workspaceInfo: .init(
                    workspaceURL: workspaceURL,
                    projectURL: projectRootURL
                )
            )
        }
    }

    @WorkspaceActor
    func acceptSuggestion(
        forFileAt fileURL: URL,
        editor: EditorContent?,
        groupIndex: Int? = nil
    ) -> CodeSuggestion? {
        refreshUpdateTime()
        guard let filespace = filespaces[fileURL] else { return nil }

        if let editor, !editor.uti.isEmpty {
            filespace.suggestionManager?.updateCursorPosition(editor.cursorPosition)
            filespaces[fileURL]?.codeMetadata.uti = editor.uti
            filespaces[fileURL]?.codeMetadata.tabSize = editor.tabSize
            filespaces[fileURL]?.codeMetadata.indentSize = editor.indentSize
            filespaces[fileURL]?.codeMetadata.usesTabsForIndentation = editor.usesTabsForIndentation
        }

        guard let suggestion = filespace.acceptSuggestion(inGroup: groupIndex) else { return nil }

        Task {
            await suggestionService?.notifyAccepted(
                suggestion,
                workspaceInfo: .init(
                    workspaceURL: workspaceURL,
                    projectURL: projectRootURL
                )
            )
        }

        return suggestion
    }

    @WorkspaceActor
    func dismissSuggestions(forFileAt fileURL: URL) {
        refreshUpdateTime()
        guard let filespace = filespaces[fileURL] else { return }
        filespace.suggestionManager?.invalidateDisplaySuggestions()
    }
}

