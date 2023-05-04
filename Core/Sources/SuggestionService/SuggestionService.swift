import Foundation

protocol SuggestionServiceType {
    func getCompletions(
        fileURL: URL,
        content: String,
        cursorPosition: CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        ignoreSpaceOnlySuggestions: Bool,
        referenceFileURL: [URL]
    ) async throws -> [CopilotCompletion]
    
    func notifyAccepted(_ completion: CopilotCompletion) async
    func notifyRejected(_ completions: [CopilotCompletion]) async
    func notifyOpenTextDocument(fileURL: URL, content: String) async throws
    func notifyChangeTextDocument(fileURL: URL, content: String) async throws
    func notifyCloseTextDocument(fileURL: URL) async throws
    func notifySaveTextDocument(fileURL: URL) async throws
}

