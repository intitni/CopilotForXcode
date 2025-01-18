import Foundation
import SuggestionBasic
import SuggestionInjector
import Workspace

// MARK: - Suggestion Control

public extension Filespace {
    @MainActor
    var activeCodeSuggestion: CodeSuggestion? {
        suggestionManager?.displaySuggestions.activeSuggestion?.activeCodeSuggestion
    }

    func setSuggestions(_ suggestions: [CodeSuggestion]) {
        Task { @WorkspaceActor in
            suggestionManager?.invalidateAllSuggestions()
            suggestionManager?.receiveSuggestions(suggestions)
        }
    }
}

extension Filespace {
    /// Get the displaying suggestion at the current index. And clear the displaying suggestions.
    ///
    /// If an index is not provided, accept the active suggestion.
    func acceptSuggestion(inGroup groupIndex: Int?) async -> CodeSuggestion? {
        guard let suggestionManager else { return nil }
        guard let suggestion = await {
            if let groupIndex {
                return await suggestionManager.displaySuggestions.suggestions[groupIndex]
            } else {
                return await suggestionManager.displaySuggestions.activeSuggestion
            }
        }()
        else { return nil }

        func finishAccepting() async {
            suggestionManager.invalidateDisplaySuggestions()
            await suggestionManager.defaultSuggestionProvider.resetSnapshot()
        }

        switch suggestion {
        case let .group(group):
            if let codeSuggestion = group.activeSuggestion {
                await finishAccepting()
                return codeSuggestion
            }
            return nil
        case let .action(action):
            await finishAccepting()
            return action.suggestion
        }
    }

    /// Reject the displaying suggestion at the current index.
    func rejectSuggestion(inGroup groupIndex: Int?) async -> [CodeSuggestion] {
        guard let suggestionManager else { return [] }

        func extractCodeSuggestions(
            _ displaySuggestion: FileSuggestionManager.DisplaySuggestion
        ) -> [CodeSuggestion] {
            switch displaySuggestion {
            case let .group(group):
                return group.suggestions
            case let .action(action):
                return [action.suggestion]
            }
        }

        let displaySuggestions = await suggestionManager.displaySuggestions
        if let groupIndex {
            if groupIndex >= 0, groupIndex < displaySuggestions.count {
                let displaySuggestions = displaySuggestions[groupIndex]
                let suggestionsInGroup = extractCodeSuggestions(displaySuggestions)
                await suggestionManager.invalidateDisplaySuggestions(inGroup: groupIndex)
                await suggestionManager.defaultSuggestionProvider.resetSnapshot()
                return suggestionsInGroup
            } else {
                return []
            }
        } else {
            let suggestions = displaySuggestions.suggestions.flatMap {
                extractCodeSuggestions($0)
            }
            suggestionManager.invalidateDisplaySuggestions()
            await suggestionManager.defaultSuggestionProvider.resetSnapshot()
            return suggestions
        }
    }

    func selectNextSuggestionGroup() {
        guard let suggestionManager else { return }
        Task {
            await suggestionManager.nextSuggestionGroup()
        }
    }

    func selectPreviousSuggestionGroup() {
        guard let suggestionManager else { return }
        Task {
            await suggestionManager.previousSuggestionGroup()
        }
    }

    func selectNextSuggestion(inGroup groupIndex: Int?) {
        guard let suggestionManager else { return }
        Task {
            let groupIndex = if let groupIndex {
                groupIndex
            } else {
                await suggestionManager.displaySuggestions.anchorIndex
            }
            await suggestionManager.nextSuggestionInGroup(index: groupIndex)
        }
    }

    func selectPreviousSuggestion(inGroup groupIndex: Int?) {
        guard let suggestionManager else { return }
        Task {
            let groupIndex = if let groupIndex {
                groupIndex
            } else {
                await suggestionManager.displaySuggestions.anchorIndex
            }
            await suggestionManager.previousSuggestionInGroup(index: groupIndex)
        }
    }
}

// MARK: - Validation

public extension Filespace {
    /// Validate the suggestion is still valid.
    /// - Parameters:
    ///    - lines: lines of the file
    ///    - cursorPosition: cursor position
    ///    - alwaysTrueIfCursorNotMoved: for unit tests
    /// - Returns: `true` if the suggestion is still valid
    @WorkspaceActor
    @discardableResult func validateSuggestions(
        lines: [String],
        cursorPosition: CursorPosition
    ) async -> Bool {
        guard let suggestionManager else { return false }
        suggestionManager.updateCursorPosition(cursorPosition)
        let displaySuggestions = await suggestionManager.displaySuggestions

        let displayedSuggestionIds = Set(
            displaySuggestions
                .flatMap { suggestion in
                    switch suggestion {
                    case let .action(action):
                        return [action.suggestion.id]
                    case let .group(group):
                        return group.suggestions.map { $0.id }
                    }
                }
        )

        for provider in suggestionManager.suggestionProviders {
            _ = provider.validateSuggestions(
                displayedSuggestionIds: displayedSuggestionIds,
                lines: lines,
                cursorPosition: cursorPosition
            )
        }

        let stillValid = suggestionManager.defaultSuggestionProvider.validateSuggestions(
            displayedSuggestionIds: displayedSuggestionIds,
            lines: lines,
            cursorPosition: cursorPosition
        )

        return stillValid
    }
}

