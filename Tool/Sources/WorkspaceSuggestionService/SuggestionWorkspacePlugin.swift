import Foundation
import Preferences
import SuggestionModel
import SuggestionProvider
import UserDefaultsObserver
import Workspace

public final class SuggestionServiceWorkspacePlugin: WorkspacePlugin {
    public typealias SuggestionServiceFactory = (
        _ projectRootURL: URL,
        _ onServiceLaunched: @escaping (any SuggestionServiceProvider) -> Void
    ) -> any SuggestionServiceProvider
    
    let userDefaultsObserver = UserDefaultsObserver(
        object: UserDefaults.shared, forKeyPaths: [
            UserDefaultPreferenceKeys().suggestionFeatureEnabledProjectList.key,
            UserDefaultPreferenceKeys().disableSuggestionFeatureGlobally.key,
        ], context: nil
    )

    public var isRealtimeSuggestionEnabled: Bool {
        UserDefaults.shared.value(for: \.realtimeSuggestionToggle)
    }

    let suggestionServiceFactory: SuggestionServiceFactory

    private var _suggestionService: SuggestionServiceProvider?

    public var suggestionService: SuggestionServiceProvider? {
        // Check if the workspace is disabled.
        let isSuggestionDisabledGlobally = UserDefaults.shared
            .value(for: \.disableSuggestionFeatureGlobally)
        if isSuggestionDisabledGlobally {
            let enabledList = UserDefaults.shared.value(for: \.suggestionFeatureEnabledProjectList)
            if !enabledList.contains(where: { path in projectRootURL.path.hasPrefix(path) }) {
                // If it's disable, remove the service
                _suggestionService = nil
                return nil
            }
        }

        if _suggestionService == nil {
            _suggestionService = suggestionServiceFactory(projectRootURL) {
                [weak self] _ in
                guard let self else { return }
                for (_, filespace) in filespaces {
                    notifyOpenFile(filespace: filespace)
                }
            }
        }
        return _suggestionService
    }

    public var isSuggestionFeatureEnabled: Bool {
        let isSuggestionDisabledGlobally = UserDefaults.shared
            .value(for: \.disableSuggestionFeatureGlobally)
        if isSuggestionDisabledGlobally {
            let enabledList = UserDefaults.shared.value(for: \.suggestionFeatureEnabledProjectList)
            if !enabledList.contains(where: { path in projectRootURL.path.hasPrefix(path) }) {
                return false
            }
        }
        return true
    }
    
    public init(
        workspace: Workspace,
        suggestionProviderFactory: @escaping SuggestionServiceFactory
    ) {
        self.suggestionServiceFactory = suggestionProviderFactory
        super.init(workspace: workspace)

        userDefaultsObserver.onChange = { [weak self] in
            guard let self else { return }
            _ = self.suggestionService
        }
    }

    override public func didOpenFilespace(_ filespace: Filespace) {
        notifyOpenFile(filespace: filespace)
    }

    override public func didSaveFilespace(_ filespace: Filespace) {
        notifySaveFile(filespace: filespace)
    }

    override public func didUpdateFilespace(_ filespace: Filespace, content: String) {
        notifyUpdateFile(filespace: filespace, content: content)
    }

    override public func didCloseFilespace(_ fileURL: URL) {
        Task {
            try await suggestionService?.notifyCloseTextDocument(fileURL: fileURL)
        }
    }

    public func notifyOpenFile(filespace: Filespace) {
        workspace?.refreshUpdateTime()
        workspace?.openedFileRecoverableStorage.openFile(fileURL: filespace.fileURL)
        Task {
            guard !(await filespace.isGitIgnored) else { return }
            // check if file size is larger than 15MB, if so, return immediately
            if let attrs = try? FileManager.default
                .attributesOfItem(atPath: filespace.fileURL.path),
                let fileSize = attrs[FileAttributeKey.size] as? UInt64,
                fileSize > 15 * 1024 * 1024
            { return }

            try await suggestionService?.notifyOpenTextDocument(
                fileURL: filespace.fileURL,
                content: String(contentsOf: filespace.fileURL, encoding: .utf8)
            )
        }
    }

    public func notifyUpdateFile(filespace: Filespace, content: String) {
        filespace.refreshUpdateTime()
        workspace?.refreshUpdateTime()
        Task {
            guard !(await filespace.isGitIgnored) else { return }
            try await suggestionService?.notifyChangeTextDocument(
                fileURL: filespace.fileURL,
                content: content
            )
        }
    }

    public func notifySaveFile(filespace: Filespace) {
        filespace.refreshUpdateTime()
        workspace?.refreshUpdateTime()
        Task {
            guard !(await filespace.isGitIgnored) else { return }
            try await suggestionService?.notifySaveTextDocument(fileURL: filespace.fileURL)
        }
    }

    public func terminateSuggestionService() async {
        await _suggestionService?.terminate()
    }
}

