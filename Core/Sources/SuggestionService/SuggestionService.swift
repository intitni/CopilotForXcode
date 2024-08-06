import BuiltinExtension
import CodeiumService
import enum CopilotForXcodeKit.SuggestionServiceError
import struct CopilotForXcodeKit.WorkspaceInfo
import Foundation
import GitHubCopilotService
import Preferences
import SuggestionBasic
import SuggestionProvider
import UserDefaultsObserver
import Workspace

#if canImport(ProExtension)
import ProExtension
#endif

public protocol SuggestionServiceType: SuggestionServiceProvider {}

public actor SuggestionService: SuggestionServiceType {
    public typealias Middleware = SuggestionServiceMiddleware
    public typealias EventHandler = SuggestionServiceEventHandler
    public var configuration: SuggestionProvider.SuggestionServiceConfiguration {
        get async { await suggestionProvider.configuration }
    }

    let middlewares: [Middleware]
    let eventHandlers: [EventHandler]

    let suggestionProvider: SuggestionServiceProvider

    public init(
        provider: any SuggestionServiceProvider,
        middlewares: [Middleware] = SuggestionServiceMiddlewareContainer.middlewares,
        eventHandlers: [EventHandler] = SuggestionServiceEventHandlerContainer.handlers
    ) {
        suggestionProvider = provider
        self.middlewares = middlewares
        self.eventHandlers = eventHandlers
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
    ) async throws -> [SuggestionBasic.CodeSuggestion] {
        do {
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
        } catch let error as SuggestionServiceError {
            throw error
        } catch {
            throw SuggestionServiceError.silent(error)
        }
    }

    func notifyAccepted(
        _ suggestion: SuggestionBasic.CodeSuggestion,
        workspaceInfo: CopilotForXcodeKit.WorkspaceInfo
    ) async {
        eventHandlers.forEach { $0.didAccept(suggestion, workspaceInfo: workspaceInfo) }
        await suggestionProvider.notifyAccepted(suggestion, workspaceInfo: workspaceInfo)
    }

    func notifyRejected(
        _ suggestions: [SuggestionBasic.CodeSuggestion],
        workspaceInfo: CopilotForXcodeKit.WorkspaceInfo
    ) async {
        eventHandlers.forEach { $0.didReject(suggestions, workspaceInfo: workspaceInfo) }
        await suggestionProvider.notifyRejected(suggestions, workspaceInfo: workspaceInfo)
    }

    func cancelRequest(workspaceInfo: CopilotForXcodeKit.WorkspaceInfo) async {
        await suggestionProvider.cancelRequest(workspaceInfo: workspaceInfo)
    }
}

