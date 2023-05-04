import Foundation
import SuggestionModel
import GitHubCopilotService

public protocol SuggestionServiceType {
    func getSuggestions(
        fileURL: URL,
        content: String,
        cursorPosition: CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        ignoreSpaceOnlySuggestions: Bool,
        referenceFileURL: [URL]
    ) async throws -> [CodeSuggestion]
    
    func notifyAccepted(_ suggestion: CodeSuggestion) async
    func notifyRejected(_ suggestions: [CodeSuggestion]) async
    func notifyOpenTextDocument(fileURL: URL, content: String) async throws
    func notifyChangeTextDocument(fileURL: URL, content: String) async throws
    func notifyCloseTextDocument(fileURL: URL) async throws
    func notifySaveTextDocument(fileURL: URL) async throws
}

public final class SuggestionService: SuggestionServiceType {
    let gitHubCopilotService: GitHubCopilotSuggestionServiceType
    
    public init(projectRootURL: URL) {
        gitHubCopilotService = GitHubCopilotSuggestionService(projectRootURL: projectRootURL)
    }
    
    public func getSuggestions(
        fileURL: URL,
        content: String,
        cursorPosition: SuggestionModel.CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        ignoreSpaceOnlySuggestions: Bool,
        referenceFileURL: [URL]
    ) async throws -> [SuggestionModel.CodeSuggestion] {
        try await gitHubCopilotService.getCompletions(
            fileURL: fileURL,
            content: content,
            cursorPosition: cursorPosition,
            tabSize: tabSize,
            indentSize: indentSize,
            usesTabsForIndentation: usesTabsForIndentation,
            ignoreSpaceOnlySuggestions: ignoreSpaceOnlySuggestions
        )
    }
    
    public func notifyAccepted(_ suggestion: SuggestionModel.CodeSuggestion) async {
        await gitHubCopilotService.notifyAccepted(suggestion)
    }
    
    public func notifyRejected(_ suggestions: [SuggestionModel.CodeSuggestion]) async {
        await gitHubCopilotService.notifyRejected(suggestions)
    }
    
    public func notifyOpenTextDocument(fileURL: URL, content: String) async throws {
        try await gitHubCopilotService.notifyOpenTextDocument(fileURL: fileURL, content: content)
    }
    
    public func notifyChangeTextDocument(fileURL: URL, content: String) async throws {
        try await gitHubCopilotService.notifyChangeTextDocument(fileURL: fileURL, content: content)
    }
    
    public func notifyCloseTextDocument(fileURL: URL) async throws {
        try await gitHubCopilotService.notifyCloseTextDocument(fileURL: fileURL)
    }
    
    public func notifySaveTextDocument(fileURL: URL) async throws {
        try await gitHubCopilotService.notifySaveTextDocument(fileURL: fileURL)
    }
}
