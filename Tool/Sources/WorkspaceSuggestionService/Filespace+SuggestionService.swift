import Foundation
import SuggestionBasic
import Workspace

public struct FilespaceSuggestionSnapshot: Equatable {
    #warning("TODO: Can we remove it?")
    public var linesHash: Int
    public var cursorPosition: CursorPosition

    public init(linesHash: Int, cursorPosition: CursorPosition) {
        self.linesHash = linesHash
        self.cursorPosition = cursorPosition
    }
}

public struct FilespaceSuggestionSnapshotKey: FilespacePropertyKey {
    public static func createDefaultValue()
        -> FilespaceSuggestionSnapshot { .init(linesHash: -1, cursorPosition: .outOfScope) }
}

public extension FilespacePropertyValues {
    @WorkspaceActor
    var suggestionSourceSnapshot: FilespaceSuggestionSnapshot {
        get { self[FilespaceSuggestionSnapshotKey.self] }
        set { self[FilespaceSuggestionSnapshotKey.self] = newValue }
    }
}

public extension Filespace {
    @WorkspaceActor
    func resetSnapshot() {
        // swiftformat:disable redundantSelf
        self.suggestionSourceSnapshot = FilespaceSuggestionSnapshotKey.createDefaultValue()
        // swiftformat:enable all
    }

    /// Validate the suggestion is still valid.
    /// - Parameters:
    ///    - lines: lines of the file
    ///    - cursorPosition: cursor position
    /// - Returns: `true` if the suggestion is still valid
    @WorkspaceActor
    func validateSuggestions(lines: [String], cursorPosition: CursorPosition) -> Bool {
        guard let presentingSuggestion else { return false }

        // cursor has moved to another line
        if cursorPosition.line != presentingSuggestion.position.line {
            reset()
            resetSnapshot()
            return false
        }

        // the cursor position is valid
        guard cursorPosition.line >= 0, cursorPosition.line < lines.count else {
            reset()
            resetSnapshot()
            return false
        }

        let editingLine = lines[cursorPosition.line].dropLast(1) // dropping line ending
        let suggestionLines = presentingSuggestion.text.split(whereSeparator: \.isNewline)
        let suggestionFirstLine = suggestionLines.first ?? ""

        /// For example:
        /// ```
        /// ABCD012     // typed text
        ///     ^
        ///     0123456 // suggestion range 4-11, generated after `ABCD`
        /// ```
        /// The suggestion should contain `012`, aka, the suggestion that is typed.
        ///
        /// Another case is that the suggestion may contain the whole line.
        /// /// ```
        /// ABCD012     // typed text
        /// ----^
        /// ABCD0123456 // suggestion range 0-11, generated after `ABCD`
        /// The suggestion should contain `ABCD012`, aka, the suggestion that is typed.
        /// ```
        let typedSuggestion = {
            assert(
                presentingSuggestion.range.start.character >= 0,
                "Generating suggestion with invalid range"
            )

            let utf16View = editingLine.utf16

            let startIndex = utf16View.index(
                utf16View.startIndex,
                offsetBy: max(0, presentingSuggestion.range.start.character),
                limitedBy: utf16View.endIndex
            ) ?? utf16View.startIndex

            let endIndex = utf16View.index(
                utf16View.startIndex,
                offsetBy: cursorPosition.character,
                limitedBy: utf16View.endIndex
            ) ?? utf16View.endIndex

            if endIndex > startIndex {
                return String(editingLine[startIndex..<endIndex])
            }

            return ""
        }()

        /// if the line will not change after accepting the suggestion
        if suggestionLines.count == 1 {
            if editingLine.hasPrefix(suggestionFirstLine),
               cursorPosition.character
               >= suggestionFirstLine.utf16.count + presentingSuggestion.range.start.character
            {
                reset()
                resetSnapshot()
                return false
            }
        }

        // the line content doesn't match the suggestion
        if cursorPosition.character > 0,
           !suggestionFirstLine.hasPrefix(typedSuggestion)
        {
            reset()
            resetSnapshot()
            return false
        }

        // finished typing the whole suggestion when the suggestion has only one line
        if typedSuggestion.hasPrefix(suggestionFirstLine), suggestionLines.count <= 1 {
            reset()
            resetSnapshot()
            return false
        }

        // undo to a state before the suggestion was generated
        if editingLine.utf16.count < presentingSuggestion.position.character {
            reset()
            resetSnapshot()
            return false
        }

        return true
    }
}

