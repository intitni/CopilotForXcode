import BuiltinExtension
import CodeiumService
import struct CopilotForXcodeKit.WorkspaceInfo
import Foundation
import GitHubCopilotService
import Preferences
import SuggestionModel
import SuggestionProvider
import UserDefaultsObserver
import Workspace

#if canImport(ProExtension)
import ProExtension
#endif

public protocol SuggestionServiceType: SuggestionServiceProvider {}

public actor SuggestionService: SuggestionServiceType {
    public var configuration: SuggestionProvider.SuggestionServiceConfiguration {
        get async { await suggestionProvider.configuration }
    }

    let middlewares: [SuggestionServiceMiddleware]

    let suggestionProvider: SuggestionServiceProvider

    public init(
        provider: any SuggestionServiceProvider,
        middlewares: [SuggestionServiceMiddleware] = SuggestionServiceMiddlewareContainer
            .middlewares
    ) {
        suggestionProvider = provider
        self.middlewares = middlewares
    }

    public static func service(
        for serviceType: SuggestionFeatureProvider = UserDefaults.shared
            .value(for: \.suggestionFeatureProvider)
    ) -> SuggestionService {
        #if canImport(ProExtension)
        if let provider = ProExtension.suggestionProviderFactory(serviceType) {
            return SuggestionService(provider: provider)
        }
        #endif

        switch serviceType {
        case .builtIn(.codeium):
            let provider = BuiltinExtensionSuggestionServiceProvider(
                extension: CodeiumExtension.self
            )
            return SuggestionService(provider: provider)
        case .builtIn(.gitHubCopilot), .extension:
            let provider = BuiltinExtensionSuggestionServiceProvider(
                extension: GitHubCopilotExtension.self
            )
            return SuggestionService(provider: provider)
        }
    }
}

public extension SuggestionService {
    func getSuggestions(
        _ request: SuggestionRequest,
        workspaceInfo: CopilotForXcodeKit.WorkspaceInfo
    ) async throws -> [SuggestionModel.CodeSuggestion] {
        var getSuggestion = suggestionProvider.getSuggestions(_:workspaceInfo:)
        let configuration = await configuration

        for middleware in middlewares.reversed() {
            getSuggestion = { [getSuggestion] request, workspaceInfo in
                try await middleware.getSuggestion(
                    request,
                    configuration: configuration,
                    next: { [getSuggestion] request in
                        try await getSuggestion(request, workspaceInfo)
                    }
                )
            }
        }

        return try await getSuggestion(request, workspaceInfo)
    }

    func notifyAccepted(
        _ suggestion: SuggestionModel.CodeSuggestion,
        workspaceInfo: CopilotForXcodeKit.WorkspaceInfo
    ) async {
        await suggestionProvider.notifyAccepted(suggestion, workspaceInfo: workspaceInfo)
    }

    func notifyRejected(
        _ suggestions: [SuggestionModel.CodeSuggestion],
        workspaceInfo: CopilotForXcodeKit.WorkspaceInfo
    ) async {
        await suggestionProvider.notifyRejected(suggestions, workspaceInfo: workspaceInfo)
    }

    func cancelRequest(workspaceInfo: CopilotForXcodeKit.WorkspaceInfo) async {
        await suggestionProvider.cancelRequest(workspaceInfo: workspaceInfo)
    }
}

