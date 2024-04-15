import Foundation
import Preferences
import SuggestionModel
import SuggestionProvider
import UserDefaultsObserver

#if canImport(ProExtension)
import ProExtension
#endif

public protocol SuggestionServiceType: SuggestionServiceProvider {}

public actor SuggestionService: SuggestionServiceType {
    public var configuration: SuggestionServiceConfiguration {
        get async { await suggestionProvider.configuration }
    }

    var middlewares: [SuggestionServiceMiddleware] {
        SuggestionServiceMiddlewareContainer.middlewares
    }

    let projectRootURL: URL
    let onServiceLaunched: (SuggestionServiceProvider) -> Void
    let providerChangeObserver = UserDefaultsObserver(
        object: UserDefaults.shared,
        forKeyPaths: [UserDefaultPreferenceKeys().suggestionFeatureProvider.key],
        context: nil
    )

    lazy var suggestionProvider: SuggestionServiceProvider = buildService()

    var serviceType: SuggestionFeatureProvider {
        UserDefaults.shared.value(for: \.suggestionFeatureProvider)
    }

    public init(
        projectRootURL: URL,
        onServiceLaunched: @escaping (SuggestionServiceProvider) -> Void
    ) {
        self.projectRootURL = projectRootURL
        self.onServiceLaunched = onServiceLaunched

        providerChangeObserver.onChange = { [weak self] in
            Task { [weak self] in
                guard let self else { return }
                await rebuildService()
            }
        }
    }

    func buildService() -> SuggestionServiceProvider {
        #if canImport(ProExtension)
        if let provider = ProExtension.suggestionProviderFactory(serviceType) {
            return provider
        }
        #endif

        switch serviceType {
        case .builtIn(.codeium):
            return CodeiumSuggestionProvider(
                projectRootURL: projectRootURL,
                onServiceLaunched: onServiceLaunched
            )
        case .builtIn(.gitHubCopilot), .extension:
            return GitHubCopilotSuggestionProvider(
                projectRootURL: projectRootURL,
                onServiceLaunched: onServiceLaunched
            )
        }
    }

    func rebuildService() {
        suggestionProvider = buildService()
    }
}

public extension SuggestionService {
    func getSuggestions(
        _ request: SuggestionRequest
    ) async throws -> [SuggestionModel.CodeSuggestion] {
        var getSuggestion = suggestionProvider.getSuggestions
        let configuration = await configuration

        for middleware in middlewares.reversed() {
            getSuggestion = { [getSuggestion] request in
                try await middleware.getSuggestion(
                    request,
                    configuration: configuration,
                    next: getSuggestion
                )
            }
        }

        return try await getSuggestion(request)
    }

    func notifyAccepted(_ suggestion: SuggestionModel.CodeSuggestion) async {
        await suggestionProvider.notifyAccepted(suggestion)
    }

    func notifyRejected(_ suggestions: [SuggestionModel.CodeSuggestion]) async {
        await suggestionProvider.notifyRejected(suggestions)
    }

    func notifyOpenTextDocument(fileURL: URL, content: String) async throws {
        try await suggestionProvider.notifyOpenTextDocument(fileURL: fileURL, content: content)
    }

    func notifyChangeTextDocument(fileURL: URL, content: String) async throws {
        try await suggestionProvider.notifyChangeTextDocument(fileURL: fileURL, content: content)
    }

    func notifyCloseTextDocument(fileURL: URL) async throws {
        try await suggestionProvider.notifyCloseTextDocument(fileURL: fileURL)
    }

    func notifySaveTextDocument(fileURL: URL) async throws {
        try await suggestionProvider.notifySaveTextDocument(fileURL: fileURL)
    }

    func cancelRequest() async {
        await suggestionProvider.cancelRequest()
    }

    func terminate() async {
        await suggestionProvider.terminate()
    }
}

