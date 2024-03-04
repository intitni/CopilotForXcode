import Foundation
import GitHubCopilotService
import Preferences
import SuggestionModel

public actor GitHubCopilotSuggestionProvider: SuggestionServiceProvider {
    public nonisolated var configuration: SuggestionServiceConfiguration {
        .init(
            acceptsRelevantCodeSnippets: true,
            mixRelevantCodeSnippetsInSource: true, 
            acceptsRelevantSnippetsFromOpenedFiles: false
        )
    }

    let projectRootURL: URL
    let onServiceLaunched: (SuggestionServiceProvider) -> Void
    var gitHubCopilotService: GitHubCopilotSuggestionServiceType?

    public init(
        projectRootURL: URL,
        onServiceLaunched: @escaping (SuggestionServiceProvider) -> Void
    ) {
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

public extension GitHubCopilotSuggestionProvider {
    func getSuggestions(_ request: SuggestionRequest) async throws
        -> [SuggestionModel.CodeSuggestion]
    {
        try await (createGitHubCopilotServiceIfNeeded()).getCompletions(
            fileURL: request.fileURL,
            content: request.content,
            cursorPosition: request.cursorPosition,
            tabSize: request.tabSize,
            indentSize: request.indentSize,
            usesTabsForIndentation: request.usesTabsForIndentation,
            ignoreSpaceOnlySuggestions: request.ignoreSpaceOnlySuggestions,
            ignoreTrailingNewLinesAndSpaces: UserDefaults.shared
                .value(for: \.gitHubCopilotIgnoreTrailingNewLines)
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

    func terminate() async {
        await (try? createGitHubCopilotServiceIfNeeded())?.terminate()
    }
}

