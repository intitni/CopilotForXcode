import AsyncAlgorithms
import BuiltinExtension
import ChatBasic
import Foundation
import XcodeInspector

#warning("This is a temporary implementation for proof of concept.")

actor BuiltinExtensionChatCompletionsService {
    typealias RequestBody = ChatCompletionsRequestBody

    enum CustomError: Swift.Error, LocalizedError {
        case chatServiceNotFound

        var errorDescription: String? {
            switch self {
            case .chatServiceNotFound:
                return "Chat service not found."
            }
        }
    }

    var extensionManager: BuiltinExtensionManager { .shared }

    let extensionIdentifier: String
    let requestBody: RequestBody

    init(extensionIdentifier: String, requestBody: RequestBody) {
        self.extensionIdentifier = extensionIdentifier
        self.requestBody = requestBody
    }
}

extension BuiltinExtensionChatCompletionsService: ChatCompletionsAPI {
    func callAsFunction() async throws -> ChatCompletionResponseBody {
        let stream: AsyncThrowingStream<ChatCompletionsStreamDataChunk, Error> =
            try await callAsFunction()

        var id: String? = nil
        var model = ""
        var content = ""
        for try await chunk in stream {
            if let chunkId = chunk.id { id = chunkId }
            if model.isEmpty, let chunkModel = chunk.model { model = chunkModel }
            content.append(chunk.message?.content ?? "")
        }

        return .init(
            id: id,
            object: "",
            model: model,
            message: .init(role: .assistant, content: content),
            otherChoices: [],
            finishReason: ""
        )
    }
}

extension BuiltinExtensionChatCompletionsService: ChatCompletionsStreamAPI {
    func callAsFunction(
    ) async throws -> AsyncThrowingStream<ChatCompletionsStreamDataChunk, Error> {
        let service = try getChatService()
        let (message, history) = extractMessageAndHistory(from: requestBody)
        guard let workspaceURL = await XcodeInspector.shared.safe.realtimeActiveWorkspaceURL,
              let projectURL = await XcodeInspector.shared.safe.realtimeActiveProjectURL
        else { throw CancellationError() }
        let stream = await service.sendMessage(
            message,
            history: history,
            references: [],
            workspace: .init(
                workspaceURL: workspaceURL,
                projectURL: projectURL
            )
        )
        let responseID = UUID().uuidString
        return stream.map { text in
            ChatCompletionsStreamDataChunk(
                id: responseID,
                object: nil,
                model: "github-copilot",
                message: .init(
                    role: .assistant,
                    content: text,
                    toolCalls: nil
                ),
                finishReason: nil
            )
        }.toStream()
    }
}

extension BuiltinExtensionChatCompletionsService {
    func getChatService() throws -> any BuiltinExtensionChatServiceType {
        guard let ext = extensionManager.extensions
            .first(where: { $0.extensionIdentifier == extensionIdentifier }),
            let service = ext.chatService as? BuiltinExtensionChatServiceType
        else {
            throw CustomError.chatServiceNotFound
        }
        return service
    }
}

extension BuiltinExtensionChatCompletionsService {
    func extractMessageAndHistory(
        from request: RequestBody
    ) -> (message: String, history: [ChatMessage]) {
        let messages = request.messages

        if let lastIndexNotUserMessage = messages.lastIndex(where: { $0.role != .user }) {
            let message = messages[(lastIndexNotUserMessage + 1)...]
                .map { $0.content }
                .joined(separator: "\n\n")
            let history = Array(messages[0...lastIndexNotUserMessage])
            return (message, history.map {
                .init(id: UUID().uuidString, role: $0.role.asChatMessageRole, content: $0.content)
            })
        } else { // everything is user message
            let message = messages.map { $0.content }.joined(separator: "\n\n")
            return (message, [])
        }
    }
}

