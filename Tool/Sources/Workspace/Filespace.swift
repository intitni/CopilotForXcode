import Environment
import Foundation
import SuggestionModel

public protocol FilespacePropertyKey {
    associatedtype Value
}

public struct FilespacePropertyValues {
    var storage: [ObjectIdentifier: Any] = [:]

    public subscript<K: WorkspacePropertyKey>(key: K.Type) -> K.Value? {
        get {
            storage[ObjectIdentifier(key)] as? K.Value
        }
        set {
            storage[ObjectIdentifier(key)] = newValue
        }
    }
}

public final class Filespace {
    public struct Snapshot: Equatable {
        public var linesHash: Int
        public var cursorPosition: CursorPosition
    }
    
    public struct CodeMetadata: Equatable {
        public var uti: String?
        public var tabSize: Int?
        public var indentSize: Int?
        public var usesTabsForIndentation: Bool?
    }

    public let fileURL: URL
    public private(set) lazy var language: String = languageIdentifierFromFileURL(fileURL).rawValue
    public var suggestions: [CodeSuggestion] = [] {
        didSet { refreshUpdateTime() }
    }

    /// stored for pseudo command handler
    public var codeMetadata: CodeMetadata = .init()
    public var suggestionIndex: Int = 0
    public var suggestionSourceSnapshot: Snapshot = .init(linesHash: -1, cursorPosition: .outOfScope)
    public var presentingSuggestion: CodeSuggestion? {
        guard suggestions.endIndex > suggestionIndex, suggestionIndex >= 0 else { return nil }
        return suggestions[suggestionIndex]
    }

    private(set) var lastSuggestionUpdateTime: Date = Environment.now()
    public var isExpired: Bool {
        Environment.now().timeIntervalSince(lastSuggestionUpdateTime) > 60 * 3
    }

    let fileSaveWatcher: FileSaveWatcher
    let onClose: (URL) -> Void

    deinit {
        onClose(fileURL)
    }

    init(
        fileURL: URL,
        onSave: @escaping (Filespace) -> Void,
        onClose: @escaping (URL) -> Void
    ) {
        self.fileURL = fileURL
        self.onClose = onClose
        fileSaveWatcher = .init(fileURL: fileURL)
        fileSaveWatcher.changeHandler = { [weak self] in
            guard let self else { return }
            onSave(self)
        }
    }

    public func reset(resetSnapshot: Bool = true) {
        suggestions = []
        suggestionIndex = 0
        if resetSnapshot {
            suggestionSourceSnapshot = .init(linesHash: -1, cursorPosition: .outOfScope)
        }
    }

    public func refreshUpdateTime() {
        lastSuggestionUpdateTime = Environment.now()
    }

    /// Validate the suggestion is still valid.
    /// - Parameters:
    ///    - lines: lines of the file
    ///    - cursorPosition: cursor position
    /// - Returns: `true` if the suggestion is still valid
    public func validateSuggestions(lines: [String], cursorPosition: CursorPosition) -> Bool {
        guard let presentingSuggestion else { return false }

        // cursor has moved to another line
        if cursorPosition.line != presentingSuggestion.position.line {
            reset()
            return false
        }

        // the cursor position is valid
        guard cursorPosition.line >= 0, cursorPosition.line < lines.count else {
            reset()
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
            return false
        }

        // finished typing the whole suggestion when the suggestion has only one line
        if editingLine.hasPrefix(suggestionFirstLine), suggestionLines.count <= 1 {
            reset()
            return false
        }

        // undo to a state before the suggestion was generated
        if editingLine.count < presentingSuggestion.position.character {
            reset()
            return false
        }

        return true
    }
}

