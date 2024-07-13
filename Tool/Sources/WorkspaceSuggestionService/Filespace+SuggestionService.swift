import Foundation
import SuggestionBasic
import SuggestionInjector
import Workspace

/// The moment when a suggestion is generated.
public struct FilespaceSuggestionSnapshot: Equatable {
    public var editingLine: String
    public var cursorPosition: CursorPosition
    public var editingLinePrefix: String
    public var editingLineSuffix: String

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

public struct FilespaceSuggestionSnapshotKey: FilespacePropertyKey {
    public static func createDefaultValue()
        -> FilespaceSuggestionSnapshot { .init(lines: [], cursorPosition: .outOfScope) }
}

public extension FilespacePropertyValues {
    /// The state of the file when a suggestion is generated.
    @WorkspaceActor
    var suggestionSourceSnapshot: FilespaceSuggestionSnapshot {
        get { self[FilespaceSuggestionSnapshotKey.self] }
        set { self[FilespaceSuggestionSnapshotKey.self] = newValue }
    }
}

public extension Filespace {
    @WorkspaceActor
    func resetSnapshot() {
        self[keyPath: \.suggestionSourceSnapshot] = FilespaceSuggestionSnapshotKey
            .createDefaultValue()
    }

    /// Validate the suggestion is still valid.
    /// - Parameters:
    ///    - lines: lines of the file
    ///    - cursorPosition: cursor position
    /// - Returns: `true` if the suggestion is still valid
    @WorkspaceActor
    func validateSuggestions(lines: [String], cursorPosition: CursorPosition) -> Bool {
        guard let presentingSuggestion else { return false }
        let snapshot = self[keyPath: \.suggestionSourceSnapshot]
        if snapshot.cursorPosition == .outOfScope { return false }

        guard Self.validateSuggestion(
            presentingSuggestion,
            snapshot: snapshot,
            lines: lines,
            cursorPosition: cursorPosition
        ) else {
            reset()
            resetSnapshot()
            return false
        }

        return true
    }
}

extension Filespace {
    static func validateSuggestion(
        _ suggestion: CodeSuggestion,
        snapshot: FilespaceSuggestionSnapshot,
        lines: [String],
        cursorPosition: CursorPosition
    ) -> Bool {
        // cursor has moved to another line
        if cursorPosition.line != suggestion.position.line { return false }

        // the cursor position is valid
        guard cursorPosition.line >= 0, cursorPosition.line < lines.count else { return false }

        let editingLine = lines[cursorPosition.line].dropLast(1) // dropping line ending
        let suggestionLines = suggestion.text.split(whereSeparator: \.isNewline)

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

    static func validateThatSuggestionMakeNoDifferent(
        _ suggestion: CodeSuggestion,
        lines: [String],
        suggestionLines: [Substring]
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
        return editingLines == originalEditingLines
    }
}

