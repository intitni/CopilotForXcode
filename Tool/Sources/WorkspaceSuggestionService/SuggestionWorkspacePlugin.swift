import BuiltinExtension
import Foundation
import Preferences
import SuggestionBasic
import SuggestionProvider
import UserDefaultsObserver
import Workspace

#if canImport(ProExtension)
import ProExtension
#endif

public final class SuggestionServiceWorkspacePlugin: WorkspacePlugin {
    public typealias SuggestionServiceFactory = () -> any SuggestionServiceProvider
    let suggestionServiceFactory: SuggestionServiceFactory

    let suggestionFeatureUsabilityObserver = UserDefaultsObserver(
        object: UserDefaults.shared, forKeyPaths: [
            UserDefaultPreferenceKeys().suggestionFeatureEnabledProjectList.key,
            UserDefaultPreferenceKeys().disableSuggestionFeatureGlobally.key,
        ], context: nil
    )

    let providerChangeObserver = UserDefaultsObserver(
        object: UserDefaults.shared,
        forKeyPaths: [UserDefaultPreferenceKeys().suggestionFeatureProvider.key],
        context: nil
    )

    public var isRealtimeSuggestionEnabled: Bool {
        UserDefaults.shared.value(for: \.realtimeSuggestionToggle)
    }

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
            _suggestionService = suggestionServiceFactory()
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
        suggestionServiceFactory = suggestionProviderFactory
        super.init(workspace: workspace)

        suggestionFeatureUsabilityObserver.onChange = { [weak self] in
            guard let self else { return }
            _ = self.suggestionService
        }

        providerChangeObserver.onChange = { [weak self] in
            guard let self else { return }
            self._suggestionService = nil
        }
    }

    func notifyAccepted(_ suggestion: CodeSuggestion) async {
        await suggestionService?.notifyAccepted(
            suggestion,
            workspaceInfo: .init(workspaceURL: workspaceURL, projectURL: projectRootURL)
        )
    }

    func notifyRejected(_ suggestions: [CodeSuggestion]) async {
        await suggestionService?.notifyRejected(
            suggestions,
            workspaceInfo: .init(workspaceURL: workspaceURL, projectURL: projectRootURL)
        )
    }
}

