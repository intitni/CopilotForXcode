import AIModel
import Foundation
import GoogleGenerativeAI
import Preferences

actor GoogleAIChatCompletionsService: ChatCompletionsAPI, ChatCompletionsStreamAPI {
    let apiKey: String
    let model: ChatModel
    var requestBody: ChatCompletionsRequestBody
    let baseURL: String

    init(
        apiKey: String,
        model: ChatModel,
        requestBody: ChatCompletionsRequestBody,
        baseURL: String
    ) {
        self.apiKey = apiKey
        self.model = model
        self.requestBody = requestBody
        self.baseURL = baseURL
    }

    func callAsFunction() async throws -> ChatCompletionResponseBody {
        let aiModel = GenerativeModel(
            name: model.info.modelName,
            apiKey: apiKey,
            generationConfig: .init(GenerationConfig(
                temperature: requestBody.temperature.map(Float.init)
            )),
            baseURL: baseURL,
            requestOptions: model.info.googleGenerativeAIInfo.apiVersion.isEmpty
                ? .init()
                : .init(apiVersion: model.info.googleGenerativeAIInfo.apiVersion)
        )
        let history = Self.convertMessages(requestBody.messages)

        do {
            let response = try await aiModel.generateContent(history)
            return response.formalized()
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
            case .promptImageContentError:
                throw error
            case .invalidAPIKey:
                throw error
            case .unsupportedUserLocation:
                throw error
            }
        } catch {
            throw error
        }
    }

    func callAsFunction() async throws
        -> AsyncThrowingStream<ChatCompletionsStreamDataChunk, Error>
    {
        let aiModel = GenerativeModel(
            name: model.info.modelName,
            apiKey: apiKey,
            generationConfig: .init(GenerationConfig(
                temperature: requestBody.temperature.map(Float.init)
            )),
            baseURL: baseURL,
            requestOptions: model.info.googleGenerativeAIInfo.apiVersion.isEmpty
                ? .init()
                : .init(apiVersion: model.info.googleGenerativeAIInfo.apiVersion)
        )
        let history = requestBody.messages.map { message in
            ModelContent(message)
        }

        let stream = AsyncThrowingStream<ChatCompletionsStreamDataChunk, Error> { continuation in
            let stream = aiModel.generateContentStream(history)
            let task = Task {
                do {
                    for try await response in stream {
                        if Task.isCancelled { break }
                        let chunk = response.formalizedAsChunk()
                        continuation.yield(chunk)
                    }
                    continuation.finish()
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
                        continuation.finish(throwing: ErrorWrapper(error: underlying))
                    case .promptBlocked:
                        continuation.finish(throwing: error)
                    case .responseStoppedEarly:
                        continuation.finish(throwing: error)
                    case .promptImageContentError:
                        continuation.finish(throwing: error)
                    case .invalidAPIKey:
                        continuation.finish(throwing: error)
                    case .unsupportedUserLocation:
                        continuation.finish(throwing: error)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }

        return stream
    }

    static func convertMessages(
        _ messages: [ChatCompletionsRequestBody.Message]
    ) -> [ModelContent] {
        var history = messages
        var reformattedHistory = [ChatCompletionsRequestBody.Message]()

        // We don't want to combine the new user message with others.
        let newUserMessage: ChatCompletionsRequestBody.Message? = if history.last?.role == .user {
            history.removeLast()
        } else {
            nil
        }

        for message in history {
            let lastIndex = reformattedHistory.endIndex - 1
            guard lastIndex >= 0 else { // first message
                if message.role == .system {
                    reformattedHistory.append(.init(
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
                let newMessage = ChatCompletionsRequestBody.Message(
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
                let dummyMessage = ChatCompletionsRequestBody.Message(
                    role: .assistant,
                    content: "OK"
                )
                reformattedHistory.append(dummyMessage)
            }
            reformattedHistory.append(newUserMessage)
        }

        return reformattedHistory.map(ModelContent.init)
    }
}

extension ModelContent {
    static func convertRole(_ role: ChatCompletionsRequestBody.Message.Role) -> String {
        switch role {
        case .user, .system, .tool:
            return "user"
        case .assistant:
            return "model"
        }
    }

    static func convertContent(of message: ChatCompletionsRequestBody.Message) -> String {
        switch message.role {
        case .system:
            return "System Prompt:\n\(message.content)"
        case .user:
            return message.content
        case .tool:
            return """
            Result of function ID: \(message.toolCallId ?? "")
            \(message.content)
            """
        case .assistant:
            if let toolCalls = message.toolCalls {
                return toolCalls.map { call in
                    return """
                    Function ID: \(call.id)
                    Call function: \(call.function.name)
                    Arguments: \(call.function.arguments ?? "{}")
                    """
                }.joined(separator: "\n")
            } else {
                return message.content
            }
        }
    }

    init(_ message: ChatCompletionsRequestBody.Message) {
        let role = Self.convertRole(message.role)
        let parts = [ModelContent.Part.text(Self.convertContent(of: message))]
        self = .init(role: role, parts: parts)
    }
}

extension GenerateContentResponse {
    func formalized() -> ChatCompletionResponseBody {
        let message: ChatCompletionResponseBody.Message
        let otherMessages: [ChatCompletionResponseBody.Message]

        func convertMessage(_ candidate: CandidateResponse) -> ChatCompletionResponseBody.Message {
            .init(
                role: .assistant,
                content: candidate.content.parts.first(where: { part in
                    if let text = part.text {
                        return !text.isEmpty
                    } else {
                        return false
                    }
                })?.text ?? ""
            )
        }

        if let first = candidates.first {
            message = convertMessage(first)
            otherMessages = candidates.dropFirst().map { convertMessage($0) }
        } else {
            message = .init(role: .assistant, content: "")
            otherMessages = []
        }

        return .init(
            object: "chat.completion",
            model: "",
            message: message,
            otherChoices: otherMessages,
            finishReason: candidates.first?.finishReason?.rawValue ?? ""
        )
    }

    func formalizedAsChunk() -> ChatCompletionsStreamDataChunk {
        func convertMessage(
            _ candidate: CandidateResponse
        ) -> ChatCompletionsStreamDataChunk.Delta {
            .init(
                role: .assistant,
                content: candidate.content.parts
                    .first(where: { $0.text != nil })?.text ?? ""
            )
        }

        return .init(
            object: "",
            model: "",
            message: candidates.first.map(convertMessage)
        )
    }
}

