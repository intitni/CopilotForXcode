import CodeiumService
import Foundation
import Preferences
import SuggestionModel

public actor CodeiumSuggestionProvider: SuggestionServiceProvider {
    public nonisolated var configuration: SuggestionServiceConfiguration {
        .init(
            acceptsRelevantCodeSnippets: true,
            mixRelevantCodeSnippetsInSource: true,
            acceptsRelevantSnippetsFromOpenedFiles: false
        )
    }

    let projectRootURL: URL
    let onServiceLaunched: (SuggestionServiceProvider) -> Void
    var codeiumService: CodeiumSuggestionServiceType?

    public init(
        projectRootURL: URL,
        onServiceLaunched: @escaping (SuggestionServiceProvider) -> Void
    ) {
        self.projectRootURL = projectRootURL
        self.onServiceLaunched = onServiceLaunched
    }

    func createCodeiumServiceIfNeeded() throws -> CodeiumSuggestionServiceType {
        if let codeiumService { return codeiumService }
        let newService = try CodeiumSuggestionService(
            projectRootURL: projectRootURL,
            onServiceLaunched: { [weak self] in
                if let self { self.onServiceLaunched(self) }
            }
        )
        codeiumService = newService

        return newService
    }
}

public extension CodeiumSuggestionProvider {
    func getSuggestions(_ request: SuggestionRequest) async throws
        -> [SuggestionModel.CodeSuggestion]
    {
        try await (createCodeiumServiceIfNeeded()).getCompletions(
            fileURL: request.fileURL,
            content: request.content,
            cursorPosition: request.cursorPosition,
            tabSize: request.tabSize,
            indentSize: request.indentSize,
            usesTabsForIndentation: request.usesTabsForIndentation,
            ignoreSpaceOnlySuggestions: request.ignoreSpaceOnlySuggestions
        )
    }

    func notifyAccepted(_ suggestion: SuggestionModel.CodeSuggestion) async {
        await (try? createCodeiumServiceIfNeeded())?.notifyAccepted(suggestion)
    }

    func notifyRejected(_: [SuggestionModel.CodeSuggestion]) async {}

    func notifyOpenTextDocument(fileURL: URL, content: String) async throws {
        try await (try? createCodeiumServiceIfNeeded())?
            .notifyOpenTextDocument(fileURL: fileURL, content: content)
    }

    func notifyChangeTextDocument(fileURL: URL, content: String) async throws {
        try await (try? createCodeiumServiceIfNeeded())?
            .notifyChangeTextDocument(fileURL: fileURL, content: content)
    }

    func notifyCloseTextDocument(fileURL: URL) async throws {
        try await (try? createCodeiumServiceIfNeeded())?
            .notifyCloseTextDocument(fileURL: fileURL)
    }

    func notifySaveTextDocument(fileURL: URL) async throws {}

    func cancelRequest() async {
        await (try? createCodeiumServiceIfNeeded())?
            .cancelRequest()
    }

    func terminate() async {
        (try? createCodeiumServiceIfNeeded())?.terminate()
    }
}

