import Environment
import Foundation
import SuggestionModel

public protocol FilespacePropertyKey {
    associatedtype Value
    static func createDefaultValue() -> Value
}

@WorkspaceActor
public final class FilespacePropertyValues {
    var storage: [ObjectIdentifier: Any] = [:]

    public subscript<K: FilespacePropertyKey>(_ key: K.Type) -> K.Value {
        get {
            if let value = storage[ObjectIdentifier(key)] as? K.Value {
                return value
            }
            let value = key.createDefaultValue()
            storage[ObjectIdentifier(key)] = value
            return value
        }
        set {
            storage[ObjectIdentifier(key)] = newValue
        }
    }
}

@WorkspaceActor
@dynamicMemberLookup
public final class Filespace {
    public let fileURL: URL
    public private(set) lazy var language: String = languageIdentifierFromFileURL(fileURL).rawValue
    public var suggestions: [CodeSuggestion] = [] {
        didSet { refreshUpdateTime() }
    }

    public var suggestionIndex: Int = 0

    public var presentingSuggestion: CodeSuggestion? {
        guard suggestions.endIndex > suggestionIndex, suggestionIndex >= 0 else { return nil }
        return suggestions[suggestionIndex]
    }

    public var isExpired: Bool {
        Environment.now().timeIntervalSince(lastSuggestionUpdateTime) > 60 * 3
    }
    
    private(set) var lastSuggestionUpdateTime: Date = Environment.now()
    var additionalProperties = FilespacePropertyValues()
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
    
    public subscript<K>(
        dynamicMember dynamicMember: WritableKeyPath<FilespacePropertyValues, K>
    ) -> K {
        get { additionalProperties[keyPath: dynamicMember] }
        set { additionalProperties[keyPath: dynamicMember] = newValue }
    }

    public func reset() {
        suggestions = []
        suggestionIndex = 0
    }

    public func refreshUpdateTime() {
        lastSuggestionUpdateTime = Environment.now()
    }
}

