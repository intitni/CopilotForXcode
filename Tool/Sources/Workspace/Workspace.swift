import Environment
import Foundation
import Preferences
import SuggestionModel
import UserDefaultsObserver

public protocol WorkspacePropertyKey {
    associatedtype Value
    static func createDefaultValue() -> Value
}

@WorkspaceActor
public class WorkspacePropertyValues {
    var storage: [ObjectIdentifier: Any] = [:]

    public subscript<K: WorkspacePropertyKey>(_ key: K.Type) -> K.Value {
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
open class WorkspacePlugin {
    public private(set) weak var workspace: Workspace?
    public var projectRootURL: URL { workspace?.projectRootURL ?? URL(fileURLWithPath: "/") }
    public var filespaces: [URL: Filespace] { workspace?.filespaces ?? [:] }

    public init(workspace: Workspace) {
        self.workspace = workspace
    }

    open func didOpenFilespace(_: Filespace) {}
    open func didSaveFilespace(_: Filespace) {}
    open func didCloseFilespace(_: URL) {}
}

@WorkspaceActor
@dynamicMemberLookup
public final class Workspace {
    public struct UnsupportedFileError: Error, LocalizedError {
        public var extensionName: String
        public var errorDescription: String? {
            "File type \(extensionName) unsupported."
        }
        
        public init(extensionName: String) {
            self.extensionName = extensionName
        }
    }

    var additionalProperties = WorkspacePropertyValues()
    public internal(set) var plugins = [ObjectIdentifier: WorkspacePlugin]()
    public let projectRootURL: URL
    public let openedFileRecoverableStorage: OpenedFileRecoverableStorage
    public private(set) var lastSuggestionUpdateTime = Environment.now()
    public var isExpired: Bool {
        Environment.now().timeIntervalSince(lastSuggestionUpdateTime) > 60 * 60 * 1
    }

    public private(set) var filespaces = [URL: Filespace]()

    let userDefaultsObserver = UserDefaultsObserver(
        object: UserDefaults.shared, forKeyPaths: [
            UserDefaultPreferenceKeys().suggestionFeatureEnabledProjectList.key,
            UserDefaultPreferenceKeys().disableSuggestionFeatureGlobally.key,
        ], context: nil
    )

    public subscript<K>(
        dynamicMember dynamicMember: WritableKeyPath<WorkspacePropertyValues, K>
    ) -> K {
        get { additionalProperties[keyPath: dynamicMember] }
        set { additionalProperties[keyPath: dynamicMember] = newValue }
    }
    
    public func plugin<P: WorkspacePlugin>(for type: P.Type) -> P? {
        plugins[ObjectIdentifier(type)] as? P
    }

    init(projectRootURL: URL) {
        self.projectRootURL = projectRootURL
        openedFileRecoverableStorage = .init(projectRootURL: projectRootURL)
        let openedFiles = openedFileRecoverableStorage.openedFiles
        for fileURL in openedFiles {
            _ = createFilespaceIfNeeded(fileURL: fileURL)
        }
    }

    public func refreshUpdateTime() {
        lastSuggestionUpdateTime = Environment.now()
    }

    public func createFilespaceIfNeeded(fileURL: URL) -> Filespace {
        let existedFilespace = filespaces[fileURL]
        let filespace = existedFilespace ?? .init(
            fileURL: fileURL,
            onSave: { [weak self] filespace in
                guard let self else { return }
                for plugin in self.plugins.values {
                    plugin.didSaveFilespace(filespace)
                }
            },
            onClose: { [weak self] url in
                guard let self else { return }
                for plugin in self.plugins.values {
                    plugin.didCloseFilespace(url)
                }
            }
        )
        if filespaces[fileURL] == nil {
            filespaces[fileURL] = filespace
        }
        if existedFilespace == nil {
            for plugin in plugins.values {
                plugin.didOpenFilespace(filespace)
            }
        } else {
            filespace.refreshUpdateTime()
        }
        return filespace
    }
    
    public func closeFilespace(fileURL: URL) {
        filespaces[fileURL] = nil
    }
}

