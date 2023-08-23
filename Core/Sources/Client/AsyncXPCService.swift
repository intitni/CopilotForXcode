import Foundation
import GitHubCopilotService
import Logger
import SuggestionModel
import XPCShared

public struct AsyncXPCService {
    public var connection: NSXPCConnection { service.connection }
    let service: XPCService

    init(service: XPCService) {
        self.service = service
    }

    public func getXPCServiceVersion() async throws -> (version: String, build: String) {
        try await withXPCServiceConnected(connection: connection) {
            service, continuation in
            service.getXPCServiceVersion { version, build in
                continuation.resume((version, build))
            }
        }
    }
    
    public func getXPCServiceAccessibilityPermission() async throws -> Bool {
        try await withXPCServiceConnected(connection: connection) {
            service, continuation in
            service.getXPCServiceAccessibilityPermission { isGranted in
                continuation.resume(isGranted)
            }
        }
    }

    public func getSuggestedCode(editorContent: EditorContent) async throws -> UpdatedContent? {
        try await suggestionRequest(
            connection,
            editorContent,
            { $0.getSuggestedCode }
        )
    }

    public func getNextSuggestedCode(editorContent: EditorContent) async throws -> UpdatedContent? {
        try await suggestionRequest(
            connection,
            editorContent,
            { $0.getNextSuggestedCode }
        )
    }

    public func getPreviousSuggestedCode(editorContent: EditorContent) async throws
        -> UpdatedContent?
    {
        try await suggestionRequest(
            connection,
            editorContent,
            { $0.getPreviousSuggestedCode }
        )
    }

    public func getSuggestionAcceptedCode(editorContent: EditorContent) async throws
        -> UpdatedContent?
    {
        try await suggestionRequest(
            connection,
            editorContent,
            { $0.getSuggestionAcceptedCode }
        )
    }

    public func getSuggestionRejectedCode(editorContent: EditorContent) async throws
        -> UpdatedContent?
    {
        try await suggestionRequest(
            connection,
            editorContent,
            { $0.getSuggestionRejectedCode }
        )
    }

    public func getRealtimeSuggestedCode(editorContent: EditorContent) async throws
        -> UpdatedContent?
    {
        try await suggestionRequest(
            connection,
            editorContent,
            { $0.getRealtimeSuggestedCode }
        )
    }
    
    public func getPromptToCodeAcceptedCode(editorContent: EditorContent) async throws
        -> UpdatedContent?
    {
        try await suggestionRequest(
            connection,
            editorContent,
            { $0.getPromptToCodeAcceptedCode }
        )
    }

    public func toggleRealtimeSuggestion() async throws {
        try await withXPCServiceConnected(connection: connection) {
            service, continuation in
            service.toggleRealtimeSuggestion { error in
                if let error {
                    continuation.reject(error)
                    return
                }
                continuation.resume(())
            }
        } as Void
    }

    public func prefetchRealtimeSuggestions(editorContent: EditorContent) async {
        guard let data = try? JSONEncoder().encode(editorContent) else { return }
        try? await withXPCServiceConnected(connection: connection) { service, continuation in
            service.prefetchRealtimeSuggestions(editorContent: data) {
                continuation.resume(())
            }
        }
    }

    public func chatWithSelection(editorContent: EditorContent) async throws -> UpdatedContent? {
        try await suggestionRequest(
            connection,
            editorContent,
            { $0.chatWithSelection }
        )
    }

    public func promptToCode(editorContent: EditorContent) async throws -> UpdatedContent? {
        try await suggestionRequest(
            connection,
            editorContent,
            { $0.promptToCode }
        )
    }

    public func customCommand(
        id: String,
        editorContent: EditorContent
    ) async throws -> UpdatedContent? {
        try await suggestionRequest(
            connection,
            editorContent,
            { service in { service.customCommand(id: id, editorContent: $0, withReply: $1) } }
        )
    }
    
    public func postNotification(name: String) async throws {
        try await withXPCServiceConnected(connection: connection) {
            service, continuation in
            service.postNotification(name: name) {
                continuation.resume(())
            }
        }
    }
    
    public func performAction(name: String, arguments: String) async throws -> String {
        try await withXPCServiceConnected(connection: connection) {
            service, continuation in
            service.performAction(name: name, arguments: arguments) {
                continuation.resume($0)
            }
        }
    }
}

struct AutoFinishContinuation<T> {
    var continuation: AsyncThrowingStream<T, Error>.Continuation

    func resume(_ value: T) {
        continuation.yield(value)
        continuation.finish()
    }

    func reject(_ error: Error) {
        if (error as NSError).code == -100 {
            continuation.finish(throwing: CancellationError())
        } else {
            continuation.finish(throwing: error)
        }
    }
}

func withXPCServiceConnected<T>(
    connection: NSXPCConnection,
    _ fn: @escaping (XPCServiceProtocol, AutoFinishContinuation<T>) -> Void
) async throws -> T {
    let stream: AsyncThrowingStream<T, Error> = AsyncThrowingStream { continuation in
        let service = connection.remoteObjectProxyWithErrorHandler {
            continuation.finish(throwing: $0)
        } as! XPCServiceProtocol
        fn(service, .init(continuation: continuation))
    }
    return try await stream.first(where: { _ in true })!
}

func suggestionRequest(
    _ connection: NSXPCConnection,
    _ editorContent: EditorContent,
    _ fn: @escaping (any XPCServiceProtocol) -> (Data, @escaping (Data?, Error?) -> Void) -> Void
) async throws -> UpdatedContent? {
    let data = try JSONEncoder().encode(editorContent)
    return try await withXPCServiceConnected(connection: connection) {
        service, continuation in
        fn(service)(data) { updatedData, error in
            if let error {
                continuation.reject(error)
                return
            }
            do {
                if let updatedData {
                    let updatedContent = try JSONDecoder()
                        .decode(UpdatedContent.self, from: updatedData)
                    continuation.resume(updatedContent)
                } else {
                    continuation.resume(nil)
                }
            } catch {
                continuation.reject(error)
            }
        }
    }
}

