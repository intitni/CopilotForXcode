import enum CopilotForXcodeKit.SuggestionServiceError
import struct CopilotForXcodeKit.WorkspaceInfo
import Foundation
import SuggestionBasic
import SuggestionProvider

extension SuggestionService: StreamingSuggestionServiceProvider {
    /// Streams partial suggestions from the provider, running every snapshot through the same
    /// middlewares as ``getSuggestions(_:workspaceInfo:)``. Providers that can't stream fall
    /// back to a single-element stream.
    public func streamSuggestions(
        _ request: SuggestionRequest,
        workspaceInfo: WorkspaceInfo
    ) async -> AsyncThrowingStream<[SuggestionBasic.CodeSuggestion], Error> {
        guard let streamingProvider = suggestionProvider as? StreamingSuggestionServiceProvider
        else {
            return SuggestionStreams.single {
                try await self.getSuggestions(request, workspaceInfo: workspaceInfo)
            }
        }

        let configuration = await configuration
        let middlewares = middlewares
        let upstream = await streamingProvider.streamSuggestions(
            request,
            workspaceInfo: workspaceInfo
        )
        return SuggestionStreams.forward(upstream, mapError: Self.wrapAsSilentIfNeeded) { partial in
            try await Self.applyMiddlewares(
                middlewares,
                to: partial,
                request: request,
                configuration: configuration
            )
        }
    }

    /// Same rule as the blocking path: unknown errors are shown nowhere but the log.
    static func wrapAsSilentIfNeeded(_ error: Error) -> Error {
        if error is CancellationError { return error }
        if error is SuggestionServiceError { return error }
        return SuggestionServiceError.silent(error)
    }

    /// Runs `suggestions` through the middleware chain as if the provider had returned them.
    static func applyMiddlewares(
        _ middlewares: [Middleware],
        to suggestions: [SuggestionBasic.CodeSuggestion],
        request: SuggestionRequest,
        configuration: SuggestionProvider.SuggestionServiceConfiguration
    ) async throws -> [SuggestionBasic.CodeSuggestion] {
        var next: (SuggestionRequest) async throws -> [SuggestionBasic.CodeSuggestion] = { _ in
            suggestions
        }
        for middleware in middlewares.reversed() {
            let inner = next
            next = { request in
                try await middleware.getSuggestion(
                    request,
                    configuration: configuration,
                    next: inner
                )
            }
        }
        return try await next(request)
    }
}
