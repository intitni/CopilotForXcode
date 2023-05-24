import Foundation
import GitHubCopilotService
import Preferences
import SuggestionModel

final class GitHubCopilotSuggestionProvider: SuggestionServiceProvider {
    let projectRootURL: URL
    let onServiceLaunched: (SuggestionServiceType) -> Void
    var gitHubCopilotService: GitHubCopilotSuggestionServiceType?

    init(projectRootURL: URL, onServiceLaunched: @escaping (SuggestionServiceType) -> Void) {
        self.projectRootURL = projectRootURL
        self.onServiceLaunched = onServiceLaunched
    }

    func createGitHubCopilotServiceIfNeeded() throws -> GitHubCopilotSuggestionServiceType {
        if let gitHubCopilotService { return gitHubCopilotService }
        let newService = try GitHubCopilotSuggestionService(projectRootURL: projectRootURL)
        gitHubCopilotService = newService
        Task {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            onServiceLaunched(self)
        }
        return newService
    }
}

extension GitHubCopilotSuggestionProvider {
    func getSuggestions(
        fileURL: URL,
        content: String,
        cursorPosition: SuggestionModel.CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        ignoreSpaceOnlySuggestions: Bool
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
    
    func cancelRequest() async {
        await (try? createGitHubCopilotServiceIfNeeded())?
            .cancelRequest()
    }
}

