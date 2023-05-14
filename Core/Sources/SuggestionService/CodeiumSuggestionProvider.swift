import CodeiumService
import Foundation
import Preferences
import SuggestionModel

final class CodeiumSuggestionProvider: SuggestionServiceProvider {
    let projectRootURL: URL
    let onServiceLaunched: (SuggestionServiceType) -> Void
    var codeiumService: CodeiumSuggestionServiceType?

    init(projectRootURL: URL, onServiceLaunched: @escaping (SuggestionServiceType) -> Void) {
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

extension CodeiumSuggestionProvider {
    func getSuggestions(
        fileURL: URL,
        content: String,
        cursorPosition: SuggestionModel.CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        ignoreSpaceOnlySuggestions: Bool
    ) async throws -> [SuggestionModel.CodeSuggestion] {
        try await (try createCodeiumServiceIfNeeded()).getCompletions(
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
}

