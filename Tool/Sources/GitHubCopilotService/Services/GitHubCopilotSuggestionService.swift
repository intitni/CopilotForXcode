import CopilotForXcodeKit
import Foundation
import SuggestionBasic
import Workspace

public final class GitHubCopilotSuggestionService: SuggestionServiceType {
    public var configuration: SuggestionServiceConfiguration {
        .init(
            acceptsRelevantCodeSnippets: true,
            mixRelevantCodeSnippetsInSource: true,
            acceptsRelevantSnippetsFromOpenedFiles: false
        )
    }

    let serviceLocator: ServiceLocatorType

    init(serviceLocator: ServiceLocatorType) {
        self.serviceLocator = serviceLocator
    }

    public func getSuggestions(
        _ request: SuggestionRequest,
        workspace: WorkspaceInfo
    ) async throws -> [CopilotForXcodeKit.CodeSuggestion] {
        guard let service = await serviceLocator.getService(from: workspace) else { return [] }
        return try await service.getCompletions(
            fileURL: request.fileURL,
            content: request.content,
            originalContent: request.originalContent,
            cursorPosition: .init(
                line: request.cursorPosition.line,
                character: request.cursorPosition.character
            ),
            tabSize: request.tabSize,
            indentSize: request.indentSize,
            usesTabsForIndentation: request.usesTabsForIndentation
        ).map(Self.convert)
    }

    public func notifyAccepted(
        _ suggestion: CopilotForXcodeKit.CodeSuggestion,
        workspace: WorkspaceInfo
    ) async {
        guard let service = await serviceLocator.getService(from: workspace) else { return }
        await service.notifyAccepted(Self.convert(suggestion))
    }

    public func notifyRejected(
        _ suggestions: [CopilotForXcodeKit.CodeSuggestion],
        workspace: WorkspaceInfo
    ) async {
        guard let service = await serviceLocator.getService(from: workspace) else { return }
        await service.notifyRejected(suggestions.map(Self.convert))
    }

    public func cancelRequest(workspace: WorkspaceInfo) async {
        guard let service = await serviceLocator.getService(from: workspace) else { return }
        await service.cancelRequest()
    }

    static func convert(
        _ suggestion: SuggestionBasic.CodeSuggestion
    ) -> CopilotForXcodeKit.CodeSuggestion {
        .init(
            id: suggestion.id,
            text: suggestion.text,
            position: .init(
                line: suggestion.position.line,
                character: suggestion.position.character
            ),
            range: .init(
                start: .init(
                    line: suggestion.range.start.line,
                    character: suggestion.range.start.character
                ),
                end: .init(
                    line: suggestion.range.end.line,
                    character: suggestion.range.end.character
                )
            )
        )
    }

    static func convert(
        _ suggestion: CopilotForXcodeKit.CodeSuggestion
    ) -> SuggestionBasic.CodeSuggestion {
        .init(
            id: suggestion.id,
            text: suggestion.text,
            position: .init(
                line: suggestion.position.line,
                character: suggestion.position.character
            ),
            range: .init(
                start: .init(
                    line: suggestion.range.start.line,
                    character: suggestion.range.start.character
                ),
                end: .init(
                    line: suggestion.range.end.line,
                    character: suggestion.range.end.character
                )
            )
        )
    }
}

