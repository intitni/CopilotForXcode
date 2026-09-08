import BuiltinExtension
import CopilotForXcodeKit
import enum CopilotForXcodeKit.SuggestionServiceError
import Foundation
import AIModel

public final class CustomModelSuggestionService: SuggestionServiceType {
    let service = CustomSuggestionCoordinator()

    public init() {}

    public var configuration: SuggestionServiceConfiguration {
        .init(
            acceptsRelevantCodeSnippets: true,
            mixRelevantCodeSnippetsInSource: false,
            acceptsRelevantSnippetsFromOpenedFiles: true
        )
    }

    public func notifyAccepted(_ suggestion: CodeSuggestion, workspace: WorkspaceInfo) async {}

    public func notifyRejected(_ suggestions: [CodeSuggestion], workspace: WorkspaceInfo) async {}

    public func cancelRequest(workspace: WorkspaceInfo) async {
        await service.cancelRequest()
    }

    public func getSuggestions(
        _ request: SuggestionRequest,
        workspace: WorkspaceInfo
    ) async throws -> [CodeSuggestion] {
        do {
            return try await service.getSuggestions(request, workspace: workspace)
        } catch {
            if let mapped = Self.userFacingError(error) { throw mapped }
            return []
        }
    }

    /// Cancellation ends the round quietly; everything else reaches the user the same way on
    /// both entry points.
    static func userFacingError(_ error: Swift.Error) -> Swift.Error? {
        if error is CancellationError { return nil }
        if let urlError = error as? URLError, urlError.code == .cancelled { return nil }
        if let error = error as? SuggestionServiceError { return error }
        return SuggestionServiceError.notice(error)
    }
}

extension CustomModelSuggestionService: StreamingSuggestionServiceType {
    public func streamSuggestions(
        _ request: SuggestionRequest,
        workspace: WorkspaceInfo
    ) async -> AsyncThrowingStream<[CodeSuggestion], Swift.Error> {
        let upstream = await service.streamSuggestions(request, workspace: workspace)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await partial in upstream {
                        continuation.yield(partial)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: Self.userFacingError(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
