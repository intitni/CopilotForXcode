import CopilotModel
import Foundation
import SuggestionInjector
import XPCShared

struct PresentInCommentSuggestionPresenter {
    func presentSuggestion(
        for filespace: Filespace,
        in workspace: Workspace,
        originalContent: String,
        lines: [String],
        cursorPosition: CursorPosition
    ) async throws -> UpdatedContent? {
        let injector = SuggestionInjector()
        var lines = lines
        var cursorPosition = cursorPosition
        var extraInfo = SuggestionInjector.ExtraInfo()

        injector.rejectCurrentSuggestions(
            from: &lines,
            cursorPosition: &cursorPosition,
            extraInfo: &extraInfo
        )

        guard let completion = await filespace.presentingSuggestion else {
            return .init(
                content: originalContent,
                newCursor: cursorPosition,
                modifications: extraInfo.modifications
            )
        }

        await injector.proposeSuggestion(
            intoContentWithoutSuggestion: &lines,
            completion: completion,
            index: filespace.suggestionIndex,
            count: filespace.suggestions.count,
            extraInfo: &extraInfo
        )

        return .init(
            content: String(lines.joined(separator: "")),
            newCursor: cursorPosition,
            modifications: extraInfo.modifications
        )
    }

    func discardSuggestion(
        for filespace: Filespace,
        in workspace: Workspace,
        originalContent: String,
        lines: [String],
        cursorPosition: CursorPosition
    ) async throws -> UpdatedContent? {
        let injector = SuggestionInjector()
        var lines = lines
        var cursorPosition = cursorPosition
        var extraInfo = SuggestionInjector.ExtraInfo()

        injector.rejectCurrentSuggestions(
            from: &lines,
            cursorPosition: &cursorPosition,
            extraInfo: &extraInfo
        )

        return .init(
            content: String(lines.joined(separator: "")),
            newCursor: cursorPosition,
            modifications: extraInfo.modifications
        )
    }
}
