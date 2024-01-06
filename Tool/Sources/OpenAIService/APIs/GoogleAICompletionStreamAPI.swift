import AIModel
import Foundation
import GoogleGenerativeAI
import Preferences

struct GoogleCompletionStreamAPI: CompletionStreamAPI {
    let apiKey: String
    let model: ChatModel
    var requestBody: CompletionRequestBody

    func callAsFunction() async throws -> AsyncThrowingStream<CompletionStreamDataChunk, Error> {
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

        let stream = AsyncThrowingStream<CompletionStreamDataChunk, Error> { continuation in
            let stream = aiModel.generateContentStream(history)
            let task = Task {
                do {
                    for try await response in stream {
                        if Task.isCancelled { break }
                        let chunk = CompletionStreamDataChunk(
                            object: "",
                            model: model.name,
                            choices: response.candidates.map { candidate in
                                .init(delta: .init(
                                    role: .assistant,
                                    content: candidate.content.parts
                                        .first(where: { $0.text != nil })?.text ?? ""
                                ))
                            }
                        )
                        continuation.yield(chunk)
                    }
                    continuation.finish()
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
}

