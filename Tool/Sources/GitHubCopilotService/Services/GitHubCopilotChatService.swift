import BuiltinExtension
import ChatBasic
import CopilotForXcodeKit
import Foundation
import LanguageServerProtocol
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
        let workDoneToken = UUID().uuidString
        let turns = convertHistory(history: history, message: message)
        let doc = GitHubCopilotDoc(
            source: editorContent?.editorContent?.content ?? "",
            tabSize: 1,
            indentSize: 4,
            insertSpaces: true,
            path: editorContent?.documentURL.path ?? "",
            uri: editorContent?.documentURL.path ?? "",
            relativePath: editorContent?.relativePath ?? "",
            languageId: editorContent?.language ?? .plaintext,
            position: editorContent?.editorContent?.cursorPosition ?? .zero
        )

        let request = GitHubCopilotRequest.ConversationCreate(requestBody: .init(
            workDoneToken: workDoneToken,
            turns: turns,
            capabilities: .init(allSkills: true, skills: []),
            doc: doc,
            source: .panel,
            workspaceFolder: workspace.projectURL.path
        ))

        let stream = AsyncThrowingStream<String, Error> { continuation in
            let startTimestamp = Date()

            continuation.onTermination = { _ in
                Task { service.unregisterNotificationHandler(id: id) }
            }

            service.registerNotificationHandler(id: id) { notification, data in
                // just incase the conversation is stuck, we will cancel it after timeout
                if Date().timeIntervalSince(startTimestamp) > 60 * 30 {
                    continuation.finish(throwing: CancellationError())
                    return false
                }

                switch notification.method {
                case "$/progress":
                    do {
                        let progress = try JSONDecoder().decode(
                            JSONRPC<StreamProgressParams>.self,
                            from: data
                        ).params
                        guard progress.token == workDoneToken else { return false }
                        if let reply = progress.value.reply, progress.value.kind == "report" {
                            continuation.yield(reply)
                        } else if progress.value.kind == "end" {
                            if let error = progress.value.error,
                               progress.value.cancellationReason == nil
                            {
                                continuation.finish(
                                    throwing: GitHubCopilotError.chatEndsWithError(error)
                                )
                            } else {
                                continuation.finish()
                            }
                        }
                        return true
                    } catch {
                        return false
                    }
                case "conversation/context":
                    do {
                        _ = try JSONDecoder().decode(
                            JSONRPC<ConversationContextParams>.self,
                            from: data
                        )
                        throw ServerError.clientDataUnavailable(CancellationError())
                    } catch {
                        return false
                    }

                default:
                    return false
                }
            }

            Task {
                do {
                    // this will return when the response is generated.
                    let createResponse = try await service.server.sendRequest(request, timeout: 120)
                    _ = try await service.server.sendRequest(
                        GitHubCopilotRequest.ConversationDestroy(requestBody: .init(
                            conversationId: createResponse.conversationId
                        ))
                    )
                } catch let error as ServerError {
                    continuation.finish(throwing: GitHubCopilotError.languageServerError(error))
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }

        return stream
    }
}

extension GitHubCopilotChatService {
    typealias Turn = GitHubCopilotRequest.ConversationCreate.RequestBody.Turn
    func convertHistory(history: [Message], message: String) -> [Turn] {
        guard let firstIndexOfUserMessage = history.firstIndex(where: { $0.role == .user })
        else { return [.init(request: message, response: nil)] }

        var currentTurn = Turn(request: "", response: nil)
        var turns: [Turn] = []
        let systemPrompt = history
            .filter { $0.role == .system }.compactMap(\.content)
            .joined(separator: "\n\n")

        if !systemPrompt.isEmpty {
            turns.append(.init(request: "[System Prompt]\n\(systemPrompt)", response: "OK!"))
        }

        for i in firstIndexOfUserMessage..<history.endIndex {
            let message = history[i]
            let text = message.content ?? ""
            switch message.role {
            case .user:
                if currentTurn.response == nil {
                    if currentTurn.request.isEmpty {
                        currentTurn.request = text
                    } else {
                        currentTurn.request += "\n\n\(text)"
                    }
                } else { // a valid turn is created
                    turns.append(currentTurn)
                    currentTurn = Turn(request: text, response: nil)
                }
            case .assistant:
                if let response = currentTurn.response {
                    currentTurn.response = "\(response)\n\n\(text)"
                } else {
                    currentTurn.response = text
                }
            default:
                break
            }
        }

        if currentTurn.response == nil {
            currentTurn.response = "OK"
        }

        turns.append(currentTurn)
        turns.append(.init(request: message, response: nil))

        return turns
    }

    func createNewMessage(references: [RetrievedContent], message: String) -> String {
        return message
    }

    struct JSONRPC<Params: Decodable>: Decodable {
        var jsonrpc: String
        var method: String
        var params: Params
    }

    struct StreamProgressParams: Decodable {
        struct Value: Decodable {
            struct Step: Decodable {
                var id: String
                var title: String
                var status: String
            }

            struct FollowUp: Decodable {
                var id: String
                var type: String
                var message: String
            }

            var kind: String
            var title: String?
            var conversationId: String
            var turnId: String
            var steps: [Step]?
            var followUp: FollowUp?
            var suggestedTitle: String?
            var reply: String?
            var annotations: [String]?
            var hideText: Bool?
            var cancellationReason: String?
            var error: String?
        }

        var token: String
        var value: Value
    }

    struct ConversationContextParams: Decodable {
        enum SkillID: String, Decodable {
            case currentEditor = "current-editor"
            case projectLabels = "project-labels"
            case recentFiles = "recent-files"
            case references
            case problemsInActiveDocument = "problems-in-active-document"
        }

        var conversationId: String
        var turnId: String
        var skillId: String
    }

    struct ConversationContextResponseBody: Encodable {}
}

