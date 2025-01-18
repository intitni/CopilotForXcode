import Dependencies
import Foundation
import GitIgnoreCheck
import IdentifiedCollections
import Perception
import SuggestionBasic

public protocol FilespacePropertyKey {
    associatedtype Value
    static func createDefaultValue() -> Value
}

public final class FilespacePropertyValues {
    private var storage: [ObjectIdentifier: Any] = [:]

    @WorkspaceActor
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

open class FilespacePlugin {
    public private(set) weak var filespace: Filespace?
    
    public init(filespace: Filespace) {
        self.filespace = filespace
    }
}

public struct FilespaceCodeMetadata: Equatable {
    public var uti: String?
    public var tabSize: Int?
    public var indentSize: Int?
    public var usesTabsForIndentation: Bool?
    public var lineEnding: String = "\n"

    init(
        uti: String? = nil,
        tabSize: Int? = nil,
        indentSize: Int? = nil,
        usesTabsForIndentation: Bool? = nil,
        lineEnding: String = "\n"
    ) {
        self.uti = uti
        self.tabSize = tabSize
        self.indentSize = indentSize
        self.usesTabsForIndentation = usesTabsForIndentation
        self.lineEnding = lineEnding
    }

    public mutating func guessLineEnding(from text: String?) {
        lineEnding = if let proposedEnding = text?.last {
            if proposedEnding.isNewline {
                String(proposedEnding)
            } else {
                "\n"
            }
        } else {
            "\n"
        }
    }
}

@dynamicMemberLookup
public final class Filespace {
    struct GitIgnoreStatus {
        var isIgnored: Bool
        var checkTime: Date
        var isExpired: Bool {
            Environment.now().timeIntervalSince(checkTime) > 60 * 3
        }
    }

    // MARK: Metadata

    public let fileURL: URL
    public private(set) lazy var language: CodeLanguage = languageIdentifierFromFileURL(fileURL)
    public var codeMetadata: FilespaceCodeMetadata = .init()
    public var isTextReadable: Bool {
        fileURL.pathExtension != "mlmodel"
    }

    // MARK: Suggestions

    public internal(set) var plugins = [ObjectIdentifier: FilespacePlugin]()

    // MARK: Life Cycle

    public var isExpired: Bool {
        Environment.now().timeIntervalSince(lastUpdateTime) > 60 * 60
    }

    public internal(set) var lastUpdateTime: Date = Environment.now()
    private var additionalProperties = FilespacePropertyValues()
    let fileSaveWatcher: FileSaveWatcher
    let onClose: (URL) -> Void

    // MARK: Git Ignore

    @WorkspaceActor
    private var gitIgnoreStatus: GitIgnoreStatus?
    @WorkspaceActor
    public var isGitIgnored: Bool {
        get async {
            @Dependency(\.gitIgnoredChecker) var gitIgnoredChecker
            @Dependency(\.date) var date

            if let gitIgnoreStatus = gitIgnoreStatus, !gitIgnoreStatus.isExpired {
                return gitIgnoreStatus.isIgnored
            }
            let isIgnored = await gitIgnoredChecker.checkIfGitIgnored(fileURL: fileURL)
            gitIgnoreStatus = .init(isIgnored: isIgnored, checkTime: date())
            return isIgnored
        }
    }

    @WorkspaceActor
    public private(set) var version: Int = 0

    // MARK: Methods

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

    #if DEBUG
    public static func preview(fileURL: URL) -> Filespace {
        Filespace(fileURL: fileURL, onSave: { _ in }, onClose: { _ in })
    }
    #endif

    @WorkspaceActor
    public subscript<K>(
        dynamicMember dynamicMember: WritableKeyPath<FilespacePropertyValues, K>
    ) -> K {
        get { additionalProperties[keyPath: dynamicMember] }
        set { additionalProperties[keyPath: dynamicMember] = newValue }
    }
    
    public func plugin<P: FilespacePlugin>(for type: P.Type) -> P? {
        plugins[ObjectIdentifier(type)] as? P
    }

    public func refreshUpdateTime() {
        lastUpdateTime = Environment.now()
    }

    @WorkspaceActor
    public func bumpVersion() {
        version += 1
    }
}

