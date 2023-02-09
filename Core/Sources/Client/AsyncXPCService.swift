import CopilotModel
import Foundation
import XPCShared

public struct AsyncXPCService {
    var connection: NSXPCConnection { service.connection }
    let service: XPCService

    init(service: XPCService) {
        self.service = service
    }

    public func checkStatus() async throws -> CopilotStatus {
        try await withXPCServiceConnected(connection: connection) {
            service, continuation in
            service.checkStatus { status, error in
                if let error {
                    continuation.reject(error)
                    return
                }
                continuation.resume(
                    status.flatMap(CopilotStatus.init(rawValue:))
                        ?? CopilotStatus.notAuthorized
                )
            }
        }
    }
    
    public func getXPCServiceVersion() async throws -> (version: String, build: String) {
        try await withXPCServiceConnected(connection: connection) {
            service, continuation in
            service.getXPCServiceVersion { version, build in
                continuation.resume((version, build))
            }
        }
    }

    public func getVersion() async throws -> String {
        try await withXPCServiceConnected(connection: connection) {
            service, continuation in
            service.getVersion { version, error in
                if let error {
                    continuation.reject(error)
                    return
                }
                continuation.resume(version ?? "--")
            }
        }
    }

    public func signInInitiate() async throws -> (verificationUri: String, userCode: String) {
        try await withXPCServiceConnected(connection: connection) {
            service, continuation in
            service.signInInitiate { verificationUri, userCode, error in
                if let error {
                    continuation.reject(error)
                    return
                }
                continuation.resume((verificationUri ?? "", userCode ?? ""))
            }
        }
    }

    public func signInConfirm(userCode: String) async throws
        -> (username: String, status: CopilotStatus)
    {
        try await withXPCServiceConnected(connection: connection) {
            service, continuation in
            service.signInConfirm(userCode: userCode) { username, status, error in
                if let error {
                    continuation.reject(error)
                    return
                }
                continuation.resume((
                    username ?? "",
                    status.flatMap(CopilotStatus.init(rawValue:)) ?? .alreadySignedIn
                ))
            }
        }
    }

    public func signOut() async throws -> CopilotStatus {
        try await withXPCServiceConnected(connection: connection) {
            service, continuation in
            service.signOut { finishstatus, error in
                if let error {
                    continuation.reject(error)
                    return
                }
                continuation
                    .resume(finishstatus.flatMap(CopilotStatus.init(rawValue:)) ?? .notSignedIn)
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
