import Foundation
import SuggestionModel
import Workspace

public struct FilespaceSuggestionSnapshot: Equatable {
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

        let editingLine = lines[cursorPosition.line].dropLast(1) // dropping \n
        let suggestionLines = presentingSuggestion.text.split(separator: "\n")
        let suggestionFirstLine = suggestionLines.first ?? ""

        // the line content doesn't match the suggestion
        if cursorPosition.character > 0,
           !suggestionFirstLine.hasPrefix(editingLine[..<(editingLine.index(
               editingLine.startIndex,
               offsetBy: cursorPosition.character,
               limitedBy: editingLine.endIndex
           ) ?? editingLine.endIndex)])
        {
            reset()
            resetSnapshot()
            return false
        }

        // finished typing the whole suggestion when the suggestion has only one line
        if editingLine.hasPrefix(suggestionFirstLine), suggestionLines.count <= 1 {
            reset()
            resetSnapshot()
            return false
        }

        // undo to a state before the suggestion was generated
        if editingLine.count < presentingSuggestion.position.character {
            reset()
            resetSnapshot()
            return false
        }

        return true
    }
}

