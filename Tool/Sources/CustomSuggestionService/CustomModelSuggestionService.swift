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
        } catch is CancellationError {
            return []
        } catch let error as URLError where error.code == .cancelled {
            return []
        } catch let error as SuggestionServiceError {
            throw error
        } catch {
            throw SuggestionServiceError.notice(error)
        }
    }
}

