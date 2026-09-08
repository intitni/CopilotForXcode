import CopilotForXcodeKit
import Foundation
import SuggestionBasic
import SuggestionProvider

/// A builtin suggestion service that can report partial results while it is still generating.
/// Element semantics are the same as ``StreamingSuggestionServiceProvider``.
public protocol StreamingSuggestionServiceType: CopilotForXcodeKit.SuggestionServiceType {
    func streamSuggestions(
        _ request: CopilotForXcodeKit.SuggestionRequest,
        workspace: WorkspaceInfo
    ) async -> AsyncThrowingStream<[CopilotForXcodeKit.CodeSuggestion], Error>
}

extension BuiltinExtensionSuggestionServiceProvider: StreamingSuggestionServiceProvider {
    public func streamSuggestions(
        _ request: SuggestionProvider.SuggestionRequest,
        workspaceInfo: CopilotForXcodeKit.WorkspaceInfo
    ) async -> AsyncThrowingStream<[SuggestionBasic.CodeSuggestion], Error> {
        guard let streaming = service as? StreamingSuggestionServiceType else {
            return SuggestionStreams.single {
                try await self.getSuggestions(request, workspaceInfo: workspaceInfo)
            }
        }
        let upstream = await streaming.streamSuggestions(request.converted, workspace: workspaceInfo)
        return SuggestionStreams.forward(upstream) { $0.map(\.converted) }
    }
}
