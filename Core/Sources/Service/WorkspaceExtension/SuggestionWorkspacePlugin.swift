import Environment
import Foundation
import UserDefaultsObserver
import Workspace
import SuggestionService
import SuggestionModel
import Preferences

final class SuggestionServiceWorkspacePlugin: WorkspacePlugin {
    let userDefaultsObserver = UserDefaultsObserver(
        object: UserDefaults.shared, forKeyPaths: [
            UserDefaultPreferenceKeys().suggestionFeatureEnabledProjectList.key,
            UserDefaultPreferenceKeys().disableSuggestionFeatureGlobally.key,
        ], context: nil
    )

    var isRealtimeSuggestionEnabled: Bool {
        UserDefaults.shared.value(for: \.realtimeSuggestionToggle)
    }

    private var _suggestionService: SuggestionServiceType?

    var suggestionService: SuggestionServiceType? {
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
            _suggestionService = SuggestionService(projectRootURL: projectRootURL) {
                [weak self] _ in
                guard let self else { return }
                for (_, filespace) in filespaces {
                    notifyOpenFile(filespace: filespace)
                }
            }
        }
        return _suggestionService
    }

    var isSuggestionFeatureEnabled: Bool {
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

    override init(workspace: Workspace) {
        super.init(workspace: workspace)

        userDefaultsObserver.onChange = { [weak self] in
            guard let self else { return }
            _ = self.suggestionService
        }
    }

    override func didOpenFilespace(_ filespace: Filespace) {
        notifyOpenFile(filespace: filespace)
    }

    override func didSaveFilespace(_ filespace: Filespace) {
        notifySaveFile(filespace: filespace)
    }
    
    override func didUpdateFilespace(_ filespace: Filespace, content: String) {
        notifyUpdateFile(filespace: filespace, content: content)
    }

    override func didCloseFilespace(_ fileURL: URL) {
        Task {
            try await suggestionService?.notifyCloseTextDocument(fileURL: fileURL)
        }
    }

    func notifyOpenFile(filespace: Filespace) {
        workspace?.refreshUpdateTime()
        workspace?.openedFileRecoverableStorage.openFile(fileURL: filespace.fileURL)
        Task {
            // check if file size is larger than 15MB, if so, return immediately
            if let attrs = try? FileManager.default
                .attributesOfItem(atPath: filespace.fileURL.path),
                let fileSize = attrs[FileAttributeKey.size] as? UInt64,
                fileSize > 15 * 1024 * 1024
            { return }

            try await suggestionService?.notifyOpenTextDocument(
                fileURL: filespace.fileURL,
                content: try String(contentsOf: filespace.fileURL, encoding: .utf8)
            )
        }
    }

    func notifyUpdateFile(filespace: Filespace, content: String) {
        filespace.refreshUpdateTime()
        workspace?.refreshUpdateTime()
        Task {
            try await suggestionService?.notifyChangeTextDocument(
                fileURL: filespace.fileURL,
                content: content
            )
        }
    }

    func notifySaveFile(filespace: Filespace) {
        filespace.refreshUpdateTime()
        workspace?.refreshUpdateTime()
        Task {
            try await suggestionService?.notifySaveTextDocument(fileURL: filespace.fileURL)
        }
    }

    func terminateSuggestionService() async {
        await _suggestionService?.terminate()
    }
}

