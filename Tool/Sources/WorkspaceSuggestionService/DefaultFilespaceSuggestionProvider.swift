import Foundation
import IdentifiedCollections
import SuggestionBasic
import SuggestionInjector
import Workspace

final class DefaultFilespaceSuggestionProvider: FilespaceSuggestionProvider {
    /// The state of the file when a suggestion is generated.
    @WorkspaceActor
    var suggestionSourceSnapshot = FilespaceSuggestionSnapshot.default

    @WorkspaceActor
    func receiveSuggestions(_ suggestions: [CodeSuggestion]) {
        codeSuggestions.append(contentsOf: suggestions)
    }

    @WorkspaceActor
    func resetSnapshot() {
        suggestionSourceSnapshot = FilespaceSuggestionSnapshot.default
    }

    /// Validate the displayed (and non-displayed) suggestions.
    ///
    /// By default, it will check only the displayed ones and see if accepting the suggestion will
    /// make any difference. If none of the suggestions are valid, the suggestion panel will be
    /// hidden.
    @WorkspaceActor
    override func validateSuggestions(
        displayedSuggestionIds: Set<CodeSuggestion.ID>,
        lines: [String],
        cursorPosition: CursorPosition
    ) -> Bool {
        return validateSuggestions(
            displayedSuggestionIds: displayedSuggestionIds,
            lines: lines,
            cursorPosition: cursorPosition,
            alwaysTrueIfCursorNotMoved: true
        )
    }
}

// MARK: - Internal

extension DefaultFilespaceSuggestionProvider {
    @WorkspaceActor
    func validateSuggestions(
        displayedSuggestionIds: Set<CodeSuggestion.ID>,
        lines: [String],
        cursorPosition: CursorPosition,
        alwaysTrueIfCursorNotMoved: Bool
    ) -> Bool {
        if suggestionSourceSnapshot.cursorPosition == .outOfScope { return false }

        guard let checkingSuggestion: CodeSuggestion = {
            var first: CodeSuggestion?
            for (index, id) in displayedSuggestionIds.enumerated() {
                guard let suggestion = codeSuggestions[id: id] else { continue }
                if !suggestion.isActionOnly {
                    return suggestion
                }
                if index == 0 {
                    first = suggestion
                }
            }
            return first
        }() else {
            return false
        }

        guard Self.validateSuggestion(
            checkingSuggestion,
            snapshot: suggestionSourceSnapshot,
            lines: lines,
            cursorPosition: cursorPosition,
            alwaysTrueIfCursorNotMoved: false
        ) else {
            codeSuggestions.removeAll { displayedSuggestionIds.contains($0.id) }
            resetSnapshot()
            return false
        }

        return true
    }
}

