import Environment
import Foundation
import Preferences
import SuggestionModel
import UserDefaultsObserver

public protocol WorkspacePropertyKey {
    associatedtype Value
}

public struct WorkspacePropertyValues {
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

open class WorkspacePlugin {
    public private(set) weak var workspace: Workspace?
    public var filespaces: [URL: Filespace] { workspace?.filespaces ?? [:] }

    public init(workspace: Workspace) {
        self.workspace = workspace
    }

    open func didOpenFilespace(_: Filespace) {}
    open func didSavedFilespace(_: Filespace) {}
    open func didCloseFilespace(_: URL) {}
}

@dynamicMemberLookup
public final class Workspace {
    public struct SuggestionFeatureDisabledError: Error, LocalizedError {
        public var errorDescription: String? {
            "Suggestion feature is disabled for this project."
        }
    }

    public struct UnsupportedFileError: Error, LocalizedError {
        public var extensionName: String
        public var errorDescription: String? {
            "File type \(extensionName) unsupported."
        }
    }

    var additionalProperties = WorkspacePropertyValues()
    var plugins = [ObjectIdentifier: WorkspacePlugin]()
    public let projectRootURL: URL
    let openedFileRecoverableStorage: OpenedFileRecoverableStorage
    public private(set) var lastSuggestionUpdateTime = Environment.now()
    public var isExpired: Bool {
        Environment.now().timeIntervalSince(lastSuggestionUpdateTime) > 60 * 60 * 1
    }

    private(set) var filespaces = [URL: Filespace]()
    var isRealtimeSuggestionEnabled: Bool {
        UserDefaults.shared.value(for: \.realtimeSuggestionToggle)
    }

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

    init(projectRootURL: URL) {
        self.projectRootURL = projectRootURL
        openedFileRecoverableStorage = .init(projectRootURL: projectRootURL)
//
//        userDefaultsObserver.onChange = { [weak self] in
//            guard let self else { return }
//            _ = self.suggestionService
//        }

        let openedFiles = openedFileRecoverableStorage.openedFiles
        for fileURL in openedFiles {
            _ = createFilespaceIfNeeded(fileURL: fileURL)
        }
    }

    public func refreshUpdateTime() {
        lastSuggestionUpdateTime = Environment.now()
    }

    func createFilespaceIfNeeded(fileURL: URL) -> Filespace {
        let existedFilespace = filespaces[fileURL]
        let filespace = existedFilespace ?? .init(
            fileURL: fileURL,
            onSave: { [weak self] filespace in
                guard let self else { return }
                for plugin in self.plugins.values {
                    plugin.didSavedFilespace(filespace)
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
}

