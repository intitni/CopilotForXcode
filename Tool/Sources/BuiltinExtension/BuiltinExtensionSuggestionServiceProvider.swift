import CopilotForXcodeKit
import Foundation
import Logger
import Preferences
import SuggestionBasic
import SuggestionProvider

public final class BuiltinExtensionSuggestionServiceProvider<
    T: BuiltinExtension
>: SuggestionServiceProvider {
    public var configuration: SuggestionServiceConfiguration {
        guard let service else {
            return .init(
                acceptsRelevantCodeSnippets: true,
                mixRelevantCodeSnippetsInSource: true,
                acceptsRelevantSnippetsFromOpenedFiles: true
            )
        }

        return service.configuration
    }

    let extensionManager: BuiltinExtensionManager

    public init(
        extension: T.Type,
        extensionManager: BuiltinExtensionManager = .shared
    ) {
        self.extensionManager = extensionManager
    }

    var service: CopilotForXcodeKit.SuggestionServiceType? {
        extensionManager.extensions.first { $0 is T }?.suggestionService
    }
    
    struct BuiltinExtensionSuggestionServiceNotFoundError: Error, LocalizedError {
        var errorDescription: String? {
            "Builtin suggestion service not found."
        }
    }

    public func getSuggestions(
        _ request: SuggestionProvider.SuggestionRequest,
        workspaceInfo: CopilotForXcodeKit.WorkspaceInfo
    ) async throws -> [SuggestionBasic.CodeSuggestion] {
        guard let service else {
            Logger.service.error("Builtin suggestion service not found.")
            throw BuiltinExtensionSuggestionServiceNotFoundError()
        }
        return try await service.getSuggestions(
            .init(
                fileURL: request.fileURL,
                relativePath: request.relativePath,
                language: .init(
                    rawValue: languageIdentifierFromFileURL(request.fileURL).rawValue
                ) ?? .plaintext,
                content: request.content, 
                originalContent: request.originalContent,
                cursorPosition: .init(
                    line: request.cursorPosition.line,
                    character: request.cursorPosition.character
                ),
                tabSize: request.tabSize,
                indentSize: request.indentSize,
                usesTabsForIndentation: request.usesTabsForIndentation,
                relevantCodeSnippets: request.relevantCodeSnippets.map { $0.converted }
            ),
            workspace: workspaceInfo
        ).map { $0.converted }
    }

    public func cancelRequest(
        workspaceInfo: CopilotForXcodeKit.WorkspaceInfo
    ) async {
        guard let service else {
            Logger.service.error("Builtin suggestion service not found.")
            return
        }
        await service.cancelRequest(workspace: workspaceInfo)
    }

    public func notifyAccepted(
        _ suggestion: SuggestionBasic.CodeSuggestion,
        workspaceInfo: CopilotForXcodeKit.WorkspaceInfo
    ) async {
        guard let service else {
            Logger.service.error("Builtin suggestion service not found.")
            return
        }
        await service.notifyAccepted(suggestion.converted, workspace: workspaceInfo)
    }

    public func notifyRejected(
        _ suggestions: [SuggestionBasic.CodeSuggestion],
        workspaceInfo: CopilotForXcodeKit.WorkspaceInfo
    ) async {
        guard let service else {
            Logger.service.error("Builtin suggestion service not found.")
            return
        }
        await service.notifyRejected(suggestions.map(\.converted), workspace: workspaceInfo)
    }
}

extension SuggestionProvider.SuggestionRequest {
    var converted: CopilotForXcodeKit.SuggestionRequest {
        .init(
            fileURL: fileURL,
            relativePath: relativePath,
            language: .init(rawValue: languageIdentifierFromFileURL(fileURL).rawValue)
                ?? .plaintext,
            content: content,
            originalContent: originalContent,
            cursorPosition: .init(
                line: cursorPosition.line,
                character: cursorPosition.character
            ),
            tabSize: tabSize,
            indentSize: indentSize,
            usesTabsForIndentation: usesTabsForIndentation,
            relevantCodeSnippets: relevantCodeSnippets.map(\.converted)
        )
    }
}

extension SuggestionBasic.CodeSuggestion {
    var converted: CopilotForXcodeKit.CodeSuggestion {
        .init(
            id: id,
            text: text,
            position: .init(
                line: position.line,
                character: position.character
            ),
            range: .init(
                start: .init(
                    line: range.start.line,
                    character: range.start.character
                ),
                end: .init(
                    line: range.end.line,
                    character: range.end.character
                )
            )
        )
    }
}

extension CopilotForXcodeKit.CodeSuggestion {
    var converted: SuggestionBasic.CodeSuggestion {
        .init(
            id: id,
            text: text,
            position: .init(
                line: position.line,
                character: position.character
            ),
            range: .init(
                start: .init(
                    line: range.start.line,
                    character: range.start.character
                ),
                end: .init(
                    line: range.end.line,
                    character: range.end.character
                )
            )
        )
    }
}

extension SuggestionProvider.RelevantCodeSnippet {
    var converted: CopilotForXcodeKit.RelevantCodeSnippet {
        .init(content: content, priority: priority, filePath: filePath)
    }
}

