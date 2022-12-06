import CopilotModel
import Foundation

struct AsyncXPCService {
    let connection: NSXPCConnection

    func checkStatus() async throws -> CopilotStatus {
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

    func getVersion() async throws -> String {
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

    func signInInitiate() async throws -> (verificationUri: String, userCode: String) {
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

    func signInConfirm(userCode: String) async throws -> (username: String, status: CopilotStatus) {
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

    func signOut() async throws -> CopilotStatus {
        try await withXPCServiceConnected(connection: connection) {
            service, continuation in
            service.signOut { finishstatus, error in
                if let error {
                    continuation.reject(error)
                    return
                }
                continuation.resume(finishstatus.flatMap(CopilotStatus.init(rawValue:)) ?? .notSignedIn)
            }
        }
    }

    func getSuggestedCode(editorContent: EditorContent) async throws -> UpdatedContent {
        try await suggestionRequest(
            connection,
            editorContent,
            { $0.getSuggestedCode }
        )
    }

    func getNextSuggestedCode(editorContent: EditorContent) async throws -> UpdatedContent {
        try await suggestionRequest(
            connection,
            editorContent,
            { $0.getNextSuggestedCode }
        )
    }

    func getPreviousSuggestedCode(editorContent: EditorContent) async throws -> UpdatedContent {
        try await suggestionRequest(
            connection,
            editorContent,
            { $0.getPreviousSuggestedCode }
        )
    }

    func getSuggestionAcceptedCode(editorContent: EditorContent) async throws -> UpdatedContent {
        try await suggestionRequest(
            connection,
            editorContent,
            { $0.getSuggestionAcceptedCode }
        )
    }

    func getSuggestionRejectedCode(editorContent: EditorContent) async throws -> UpdatedContent {
        try await suggestionRequest(
            connection,
            editorContent,
            { $0.getSuggestionRejectedCode }
        )
    }
}

private struct AutoFinishContinuation<T> {
    var continuation: AsyncThrowingStream<T, Error>.Continuation

    func resume(_ value: T) {
        continuation.yield(value)
        continuation.finish()
    }

    func reject(_ error: Error) {
        continuation.finish(throwing: error)
    }
}

private func withXPCServiceConnected<T>(
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

private func suggestionRequest(
    _ connection: NSXPCConnection,
    _ editorContent: EditorContent,
    _ fn: @escaping (any XPCServiceProtocol) -> (Data, @escaping (Data?, Error?) -> Void) -> Void
) async throws -> UpdatedContent {
    let data = try JSONEncoder().encode(editorContent)
    return try await withXPCServiceConnected(connection: connection) {
        service, continuation in
        fn(service)(data) { updatedData, error in
            if let error {
                continuation.reject(error)
                return
            }
            do {
                let updatedContent = try JSONDecoder()
                    .decode(UpdatedContent.self, from: updatedData ?? Data())
                continuation.resume(updatedContent)
            } catch {
                continuation.reject(error)
            }
        }
    }
}
