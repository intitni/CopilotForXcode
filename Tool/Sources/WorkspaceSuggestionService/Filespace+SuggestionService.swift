import Foundation
import SuggestionBasic
import SuggestionInjector
import Workspace

// MARK: - Suggestion Control

public extension Filespace {
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
    @WorkspaceActor
    func acceptSuggestion(inGroup groupIndex: Int?) -> CodeSuggestion? {
        guard let suggestionManager else { return nil }
        guard let suggestion = {
            if let groupIndex {
                return suggestionManager.displaySuggestions.suggestions[groupIndex]
            } else {
                return suggestionManager.displaySuggestions.activeSuggestion
            }
        }()
        else { return nil }

        func finishAccepting() {
            suggestionManager.invalidateDisplaySuggestions()
            suggestionManager.defaultSuggestionProvider.resetSnapshot()
        }

        switch suggestion {
        case let .group(group):
            if let codeSuggestion = group.activeSuggestion {
                finishAccepting()
                return codeSuggestion
            }
            return nil
        case let .action(action):
            finishAccepting()
            return action.suggestion
        }
    }

    /// Reject the displaying suggestion at the current index.
    @WorkspaceActor
    func rejectSuggestion(inGroup groupIndex: Int?) -> [CodeSuggestion] {
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

        if let groupIndex {
            if groupIndex >= 0, groupIndex < suggestionManager.displaySuggestions.count {
                let displaySuggestions = suggestionManager.displaySuggestions[groupIndex]
                let suggestionsInGroup = extractCodeSuggestions(displaySuggestions)
                suggestionManager.invalidateDisplaySuggestions(inGroup: groupIndex)
                suggestionManager.defaultSuggestionProvider.resetSnapshot()
                return suggestionsInGroup
            } else {
                return []
            }
        } else {
            let suggestions = suggestionManager.displaySuggestions.suggestions.flatMap {
                extractCodeSuggestions($0)
            }
            suggestionManager.invalidateDisplaySuggestions()
            suggestionManager.defaultSuggestionProvider.resetSnapshot()
            return suggestions
        }
    }

    @WorkspaceActor
    func selectNextSuggestionGroup() {
        guard let suggestionManager else { return }
        suggestionManager.nextSuggestionGroup()
    }

    @WorkspaceActor
    func selectPreviousSuggestionGroup() {
        guard let suggestionManager else { return }
        suggestionManager.previousSuggestionGroup()
    }

    @WorkspaceActor
    func selectNextSuggestion(inGroup groupIndex: Int?) {
        guard let suggestionManager else { return }
        let groupIndex = groupIndex ?? suggestionManager.displaySuggestions.anchorIndex
        suggestionManager.nextSuggestionInGroup(index: groupIndex)
    }

    @WorkspaceActor
    func selectPreviousSuggestion(inGroup groupIndex: Int?) {
        guard let suggestionManager else { return }
        let groupIndex = groupIndex ?? suggestionManager.displaySuggestions.anchorIndex
        suggestionManager.previousSuggestionInGroup(index: groupIndex)
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
    ) -> Bool {
        guard let suggestionManager else { return false }
        suggestionManager.updateCursorPosition(cursorPosition)

        let displayedSuggestionIds = Set(
            suggestionManager.displaySuggestions
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

