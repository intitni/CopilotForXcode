import Foundation
import SuggestionModel
import GitHubCopilotService

protocol SuggestionServiceType {
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
    func getSuggestions(fileURL: URL, content: String, cursorPosition: SuggestionModel.CursorPosition, tabSize: Int, indentSize: Int, usesTabsForIndentation: Bool, ignoreSpaceOnlySuggestions: Bool, referenceFileURL: [URL]) async throws -> [SuggestionModel.CodeSuggestion] {
        fatalError()
    }
    
    func notifyAccepted(_ suggestion: SuggestionModel.CodeSuggestion) async {
        fatalError()
    }
    
    func notifyRejected(_ suggestions: [SuggestionModel.CodeSuggestion]) async {
        fatalError()
    }
    
    func notifyOpenTextDocument(fileURL: URL, content: String) async throws {
        fatalError()
    }
    
    func notifyChangeTextDocument(fileURL: URL, content: String) async throws {
        fatalError()
    }
    
    func notifyCloseTextDocument(fileURL: URL) async throws {
        fatalError()
    }
    
    func notifySaveTextDocument(fileURL: URL) async throws {
        fatalError()
    }
}
