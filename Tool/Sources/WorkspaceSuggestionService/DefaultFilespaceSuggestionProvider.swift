import Foundation
import IdentifiedCollections
import SuggestionBasic
import SuggestionInjector
import Workspace

open class FilespaceSuggestionProvider {
    weak var delegate: FilespaceSuggestionProviderDelegate?

    @WorkspaceActor
    public var codeSuggestions: IdentifiedArrayOf<CodeSuggestion> = [] {
        didSet {
            delegate?.onCodeSuggestionChange()
        }
    }

    @WorkspaceActor
    open func invalidateSuggestion(id: CodeSuggestion.ID) {
        codeSuggestions.remove(id: id)
    }

    @WorkspaceActor
    open func invalidateAllSuggestion() {
        codeSuggestions.removeAll()
    }

    @WorkspaceActor
    open func invalidateSuggestions(after position: CursorPosition) {
        codeSuggestions.removeAll { $0.position > position }
    }

    /// Validate the displayed (and non-displayed) suggestions.
    @WorkspaceActor
    open func validateSuggestions(
        displayedSuggestionIds: Set<CodeSuggestion.ID>,
        lines: [String],
        cursorPosition: CursorPosition
    ) -> Bool {
        return false
    }
}

protocol FilespaceSuggestionProviderDelegate: AnyObject {
    func onCodeSuggestionChange()
}

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
        if suggestionSourceSnapshot.cursorPosition == .outOfScope { return false }

        guard let checkingSuggestion = displayedSuggestionIds
            .compactMap({ codeSuggestions[id: $0] })
            .first
        else { return false }

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

extension FilespaceSuggestionProvider {
    static func validateSuggestion(
        _ suggestion: CodeSuggestion,
        snapshot: FilespaceSuggestionSnapshot,
        lines: [String],
        cursorPosition: CursorPosition,
        // For test
        alwaysTrueIfCursorNotMoved: Bool = true
    ) -> Bool {
        // cursor is not even moved during the generation.
        if alwaysTrueIfCursorNotMoved, cursorPosition == suggestion.position { return true }

        // cursor has moved to another line
        if cursorPosition.line != suggestion.position.line { return false }

        // the cursor position is valid
        guard cursorPosition.line >= 0, cursorPosition.line < lines.count else { return false }

        let editingLine = lines[cursorPosition.line].dropLast(1) // dropping line ending
        let suggestionLines = suggestion.text.breakLines(appendLineBreakToLastLine: true)

        if Self.validateThatIsNotTypingSuggestion(
            suggestion,
            snapshot: snapshot,
            lines: lines,
            suggestionLines: suggestionLines,
            cursorPosition: cursorPosition
        ) {
            return false
        }

        // if the line will not change after accepting the suggestion
        if Self.validateThatSuggestionMakeNoDifferent(
            suggestion,
            lines: lines,
            suggestionLines: suggestionLines
        ) {
            return false
        }

        // the line content doesn't match the suggestion snapshot
        if !editingLine.hasPrefix(snapshot.editingLinePrefix) {
            return false
        }

        return true
    }

    static func validateThatIsNotTypingSuggestion(
        _ suggestion: CodeSuggestion,
        snapshot: FilespaceSuggestionSnapshot,
        lines: [String],
        suggestionLines: [String],
        cursorPosition: CursorPosition
    ) -> Bool {
        let lineIndex = suggestion.range.start.line
        let typeStart = suggestion.position.character
        let cursorColumn = cursorPosition.character
        let suggestionStart = max(
            0,
            suggestion.position.character - suggestion.range.start.character
        )
        func contentBeforeCursor(
            _ string: String,
            start: Int
        ) -> ArraySlice<String.UTF16View.Element> {
            if start >= cursorColumn { return [] }
            let elements = Array(string.utf16)
            guard start >= 0, start < elements.endIndex else { return [] }
            let endIndex = min(elements.endIndex, cursorColumn)
            return elements[start..<endIndex]
        }

        guard lineIndex >= 0, lineIndex < lines.endIndex else { return false }
        let editingLine = lines[lineIndex]
        let suggestionFirstLine = suggestionLines.first ?? ""

        let typed = contentBeforeCursor(editingLine, start: typeStart)
        let expectedTyped = contentBeforeCursor(suggestionFirstLine, start: suggestionStart)
        return typed != expectedTyped
    }

    static func validateThatSuggestionMakeNoDifferent(
        _ suggestion: CodeSuggestion,
        lines: [String],
        suggestionLines: [String]
    ) -> Bool {
        var editingRange = suggestion.range
        let startLine = max(0, editingRange.start.line)
        let endLine = max(startLine, min(editingRange.end.line, lines.count - 1))

        // The editing range is out of the file
        if startLine < 0 || endLine >= lines.count {
            return false
        }

        // The suggestion is apparently longer than the editing range
        if endLine - startLine + 1 != suggestionLines.count {
            return false
        }

        let originalEditingLines = Array(lines[startLine...endLine])
        var editingLines = originalEditingLines
        editingRange.end = .init(
            line: editingRange.end.line - editingRange.start.line,
            character: editingRange.end.character
        )
        editingRange.start = .init(line: 0, character: editingRange.start.character)
        var cursorPosition = CursorPosition(
            line: suggestion.position.line - startLine,
            character: suggestion.position.character
        )
        let pseudoSuggestion = CodeSuggestion(
            id: "",
            text: suggestion.text,
            position: cursorPosition,
            range: editingRange
        )
        var extraInfo = SuggestionInjector.ExtraInfo()
        let injector = SuggestionInjector()
        injector.acceptSuggestion(
            intoContentWithoutSuggestion: &editingLines,
            cursorPosition: &cursorPosition,
            completion: pseudoSuggestion,
            extraInfo: &extraInfo
        )

        // We want that finish typing a partial suggestion should also make no difference.
        if let lastOriginalLine = originalEditingLines.last,
           cursorPosition.character < lastOriginalLine.utf16.count,
           // But we also want to separate this case from the case that the suggestion is
           // shortening the last line. Which does make a difference.
           suggestion.range.end.character < lastOriginalLine.utf16.count - 1 // for line ending
        {
            let editingLinesPrefix = editingLines.dropLast()
            let originalEditingLinesPrefix = originalEditingLines.dropLast()
            if editingLinesPrefix != originalEditingLinesPrefix {
                return false
            }
            let lastEditingLine = editingLines.last ?? "\n"
            return lastOriginalLine.hasPrefix(lastEditingLine.dropLast(1)) // for line ending
        }

        return editingLines == originalEditingLines
    }
}

/// The moment when a suggestion is generated.
public struct FilespaceSuggestionSnapshot: Equatable {
    public var editingLine: String
    public var cursorPosition: CursorPosition
    public var editingLinePrefix: String
    public var editingLineSuffix: String

    public static var `default` = FilespaceSuggestionSnapshot(
        lines: [],
        cursorPosition: .outOfScope
    )

    public static func == (
        lhs: FilespaceSuggestionSnapshot,
        rhs: FilespaceSuggestionSnapshot
    ) -> Bool {
        lhs.editingLine == rhs.editingLine
            && lhs.cursorPosition == rhs.cursorPosition
    }

    public init(lines: [String], cursorPosition: CursorPosition) {
        self.cursorPosition = cursorPosition
        editingLine = if cursorPosition.line >= 0 && cursorPosition.line < lines.count {
            lines[cursorPosition.line]
        } else {
            ""
        }
        let col = cursorPosition.character
        let view = editingLine.utf16
        editingLinePrefix = if col >= 0 {
            String(view.prefix(col)) ?? ""
        } else {
            ""
        }
        editingLineSuffix = if col >= 0, col < editingLine.utf16.count {
            String(view[view.index(view.startIndex, offsetBy: col)...]) ?? ""
        } else {
            ""
        }
    }
}

