import AIModel
import Foundation
import GoogleGenerativeAI
import Preferences

struct GoogleCompletionAPI: CompletionAPI {
    let apiKey: String
    let model: ChatModel
    var requestBody: CompletionRequestBody
    let prompt: ChatGPTPrompt

    func callAsFunction() async throws -> CompletionResponseBody {
        let aiModel = GenerativeModel(
            name: model.info.modelName,
            apiKey: apiKey,
            generationConfig: .init(GenerationConfig(
                temperature: requestBody.temperature.map(Float.init),
                topP: requestBody.top_p.map(Float.init)
            ))
        )
        let history = prompt.googleAICompatible.history.map { message in
            ModelContent(
                ChatMessage(
                    role: message.role,
                    content: message.content,
                    name: message.name,
                    functionCall: message.functionCall.map {
                        .init(name: $0.name, arguments: $0.arguments)
                    }
                )
            )
        }

        do {
            let response = try await aiModel.generateContent(history)

            return .init(
                object: "chat.completion",
                model: model.info.modelName,
                usage: .init(prompt_tokens: 0, completion_tokens: 0, total_tokens: 0),
                choices: response.candidates.enumerated().map {
                    let (index, candidate) = $0
                    return .init(
                        message: .init(
                            role: .assistant,
                            content: candidate.content.parts.first(where: { part in
                                if let text = part.text {
                                    return !text.isEmpty
                                } else {
                                    return false
                                }
                            })?.text ?? ""
                        ),
                        index: index,
                        finish_reason: candidate.finishReason?.rawValue ?? ""
                    )
                }
            )
        } catch let error as GenerateContentError {
            struct ErrorWrapper: Error, LocalizedError {
                let error: Error
                var errorDescription: String? {
                    var s = ""
                    dump(error, to: &s)
                    return "Internal Error: \(s)"
                }
            }

            switch error {
            case let .internalError(underlying):
                throw ErrorWrapper(error: underlying)
            case .promptBlocked:
                throw error
            case .responseStoppedEarly:
                throw error
            }
        } catch {
            throw error
        }
    }
}

extension ChatGPTPrompt {
    var googleAICompatible: ChatGPTPrompt {
        var history = self.history
        var reformattedHistory = [ChatMessage]()

        // We don't want to combine the new user message with others.
        let newUserMessage: ChatMessage? = if history.last?.role == .user {
            history.removeLast()
        } else {
            nil
        }

        for message in history {
            let lastIndex = reformattedHistory.endIndex - 1
            guard lastIndex >= 0 else { // first message
                if message.role == .system {
                    reformattedHistory.append(.init(
                        id: message.id,
                        role: .user,
                        content: ModelContent.convertContent(of: message)
                    ))
                    reformattedHistory.append(.init(
                        role: .assistant,
                        content: "Got it. Let's start our conversation."
                    ))
                    continue
                }

                reformattedHistory.append(message)
                continue
            }

            let lastMessage = reformattedHistory[lastIndex]

            if ModelContent.convertRole(lastMessage.role) == ModelContent
                .convertRole(message.role)
            {
                let newMessage = ChatMessage(
                    id: message.id,
                    role: message.role == .assistant ? .assistant : .user,
                    content: """
                    \(ModelContent.convertContent(of: lastMessage))

                    ======

                    \(ModelContent.convertContent(of: message))
                    """
                )
                reformattedHistory[lastIndex] = newMessage
            } else {
                reformattedHistory.append(message)
            }
        }

        if let newUserMessage {
            if let last = reformattedHistory.last,
               ModelContent.convertRole(last.role) == ModelContent
               .convertRole(newUserMessage.role)
            {
                // Add dummy message
                let dummyMessage = ChatMessage(
                    role: .assistant,
                    content: "OK"
                )
                reformattedHistory.append(dummyMessage)
            }
            reformattedHistory.append(newUserMessage)
        }

        return .init(
            history: reformattedHistory,
            references: references,
            remainingTokenCount: remainingTokenCount
        )
    }
}

extension ModelContent {
    static func convertRole(_ role: ChatMessage.Role) -> String {
        switch role {
        case .user, .system, .function:
            return "user"
        case .assistant:
            return "model"
        }
    }

    static func convertContent(of message: ChatMessage) -> String {
        switch message.role {
        case .system:
            return "System Prompt:\n\(message.content ?? " ")"
        case .user:
            return message.content ?? " "
        case .function:
            return """
            Result of \(message.name ?? "function"): \(message.content ?? "N/A")
            """
        case .assistant:
            if let functionCall = message.functionCall {
                return """
                Call function: \(functionCall.name)
                Arguments: \(functionCall.arguments)
                """
            } else {
                return message.content ?? " "
            }
        }
    }

    init(_ message: ChatMessage) {
        let role = Self.convertRole(message.role)
        let parts = [ModelContent.Part.text(Self.convertContent(of: message))]
        self = .init(role: role, parts: parts)
    }
}

