import Foundation
import GitHubCopilotService
import SuggestionModel

public protocol SuggestionServiceType {
    func getSuggestions(
        fileURL: URL,
        content: String,
        cursorPosition: CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        ignoreSpaceOnlySuggestions: Bool,
        referenceFileURLs: [URL]
    ) async throws -> [CodeSuggestion]

    func notifyAccepted(_ suggestion: CodeSuggestion) async
    func notifyRejected(_ suggestions: [CodeSuggestion]) async
    func notifyOpenTextDocument(fileURL: URL, content: String) async throws
    func notifyChangeTextDocument(fileURL: URL, content: String) async throws
    func notifyCloseTextDocument(fileURL: URL) async throws
    func notifySaveTextDocument(fileURL: URL) async throws
}

public final class SuggestionService: SuggestionServiceType {
    let projectRootURL: URL
    let onServiceLaunched: (SuggestionServiceType) -> Void
    var gitHubCopilotService: GitHubCopilotSuggestionServiceType?

    public init(projectRootURL: URL, onServiceLaunched: @escaping (SuggestionServiceType) -> Void) {
        self.projectRootURL = projectRootURL
        self.onServiceLaunched = onServiceLaunched
    }

    func createGitHubCopilotServiceIfNeeded() throws -> GitHubCopilotSuggestionServiceType {
        if let gitHubCopilotService { return gitHubCopilotService }
        let newService = try GitHubCopilotSuggestionService()
        gitHubCopilotService = newService
        Task {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            onServiceLaunched(self)
        }
        return newService
    }
}

public extension SuggestionService {
    func getSuggestions(
        fileURL: URL,
        content: String,
        cursorPosition: SuggestionModel.CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        ignoreSpaceOnlySuggestions: Bool,
        referenceFileURLs: [URL]
    ) async throws -> [SuggestionModel.CodeSuggestion] {
        try await (try createGitHubCopilotServiceIfNeeded()).getCompletions(
            fileURL: fileURL,
            content: content,
            cursorPosition: cursorPosition,
            tabSize: tabSize,
            indentSize: indentSize,
            usesTabsForIndentation: usesTabsForIndentation,
            ignoreSpaceOnlySuggestions: ignoreSpaceOnlySuggestions
        )
    }

    func notifyAccepted(_ suggestion: SuggestionModel.CodeSuggestion) async {
        await (try? createGitHubCopilotServiceIfNeeded())?.notifyAccepted(suggestion)
    }

    func notifyRejected(_ suggestions: [SuggestionModel.CodeSuggestion]) async {
        await (try? createGitHubCopilotServiceIfNeeded())?.notifyRejected(suggestions)
    }

    func notifyOpenTextDocument(fileURL: URL, content: String) async throws {
        try await (try? createGitHubCopilotServiceIfNeeded())?
            .notifyOpenTextDocument(fileURL: fileURL, content: content)
    }

    func notifyChangeTextDocument(fileURL: URL, content: String) async throws {
        try await (try? createGitHubCopilotServiceIfNeeded())?
            .notifyChangeTextDocument(fileURL: fileURL, content: content)
    }

    func notifyCloseTextDocument(fileURL: URL) async throws {
        try await (try? createGitHubCopilotServiceIfNeeded())?
            .notifyCloseTextDocument(fileURL: fileURL)
    }

    func notifySaveTextDocument(fileURL: URL) async throws {
        try await (try? createGitHubCopilotServiceIfNeeded())?
            .notifySaveTextDocument(fileURL: fileURL)
    }
}

