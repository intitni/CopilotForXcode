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
            name: model.name,
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

        let response = try await aiModel.generateContent(history)

        return .init(
            object: "chat.completion",
            model: model.name,
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
    }
}

