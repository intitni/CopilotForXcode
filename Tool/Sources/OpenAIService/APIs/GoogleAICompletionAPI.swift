import AIModel
import Foundation
import GoogleGenerativeAI
import Preferences

struct GoogleCompletionAPI: CompletionAPI {
    let apiKey: String
    let model: ChatModel
    var requestBody: CompletionRequestBody

    func callAsFunction() async throws -> CompletionResponseBody {
        let aiModel = GenerativeModel(
            name: model.info.modelName,
            apiKey: apiKey,
            generationConfig: .init(GenerationConfig(
                temperature: requestBody.temperature.map(Float.init),
                topP: requestBody.top_p.map(Float.init)
            ))
        )
        let history = requestBody.messages.map { message in
            ModelContent(
                ChatMessage(
                    role: message.role,
                    content: message.content,
                    name: message.name,
                    functionCall: message.function_call.map {
                        .init(name: $0.name, arguments: $0.arguments ?? "")
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

