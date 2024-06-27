import BuiltinExtension
import CopilotForXcodeKit
import Foundation
import XcodeInspector

public final class GitHubCopilotChatService: BuiltinExtensionChatServiceType {
    let serviceLocator: any ServiceLocatorType

    init(serviceLocator: any ServiceLocatorType) {
        self.serviceLocator = serviceLocator
    }

    /// - note: Let's do it in a naive way for proof of concept. We will create a new chat for each
    /// message in this version.
    public func sendMessage(
        _ message: String,
        history: [Message],
        references: [RetrievedContent],
        workspace: WorkspaceInfo
    ) async -> AsyncThrowingStream<String, Error> {
        guard let service = await serviceLocator.getService(from: workspace)
        else { return .finished(throwing: CancellationError()) }
        let id = UUID().uuidString
        let editorContent = await XcodeInspector.shared.getFocusedEditorContent()
        do {
            let createResponse = try await service.server
                .sendRequest(GitHubCopilotRequest.ConversationCreate(requestBody: .init(
                    workDoneToken: "",
                    turns: convertHistory(history: history),
                    capabilities: [
                        .init(allSkills: true, skills: []),
                    ],
                    doc: .init(
                        source: editorContent?.editorContent?.content ?? "",
                        tabSize: 1,
                        indentSize: 4,
                        insertSpaces: true,
                        path: editorContent?.documentURL.path ?? "",
                        uri: editorContent?.documentURL.path ?? "",
                        relativePath: editorContent?.relativePath ?? "",
                        languageId: editorContent?.language.rawValue ?? "plaintext",
                        position: .zero
                    ),
                    source: .panel,
                    workspaceFolder: workspace.projectURL.path
                )))

            let stream = AsyncThrowingStream<String, Error>.init { continuation in
                service.registerNotificationHandler(id: id) { notification in
                    if notification.method.rawValue == "" {
                        return true
                    }

                    return false
                }

                continuation.onTermination = { _ in
                    Task {
                        try await service.server.sendRequest(
                            GitHubCopilotRequest.ConversationDestroy(requestBody: .init(
                                conversationId: createResponse.conversationId
                            ))
                        )
                    }
                }
            }

            _ = try await service.server
                .sendRequest(GitHubCopilotRequest.ConversationTurn(requestBody: .init(
                    workDoneToken: "",
                    conversationId: createResponse.conversationId,
                    message: message
                )))

            return stream
        } catch {
            return .finished(throwing: error)
        }
    }
}

extension GitHubCopilotChatService {
    typealias Turn = GitHubCopilotRequest.ConversationCreate.RequestBody.Turn
    func convertHistory(history: [Message]) -> [Turn] {
        guard let firstIndexOfUserMessage = history.firstIndex(where: { $0.role == .user })
        else { return [] }

        var currentTurn = Turn(request: "", response: nil)
        var turns: [Turn] = []
        for i in firstIndexOfUserMessage..<history.endIndex {
            let message = history[i]
            switch message.role {
            case .user:
                if currentTurn.response == nil {
                    if currentTurn.request.isEmpty {
                        currentTurn.request = message.text
                    } else {
                        currentTurn.request += "\n\n\(message.text)"
                    }
                } else { // a valid turn is created
                    turns.append(currentTurn)
                    currentTurn = Turn(request: message.text, response: nil)
                }
            case .assistant:
                if let response = currentTurn.response {
                    currentTurn.response = "\(response)\n\n\(message.text)"
                } else {
                    currentTurn.response = message.text
                }
            default:
                break
            }
        }

        if currentTurn.response == nil {
            currentTurn.response = "OK"
        }

        turns.append(currentTurn)

        return turns
    }

    func createNewMessage(references: [RetrievedContent], message: String) -> String {
        return message
    }
}

