import AIModel
import Foundation
import GoogleGenerativeAI
import Preferences

struct GoogleCompletionStreamAPI: CompletionStreamAPI {
    let apiKey: String
    let model: ChatModel
    var requestBody: CompletionRequestBody
    let prompt: ChatGPTPrompt

    func callAsFunction() async throws -> AsyncThrowingStream<CompletionStreamDataChunk, Error> {
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

        let stream = AsyncThrowingStream<CompletionStreamDataChunk, Error> { continuation in
            let stream = aiModel.generateContentStream(history)
            let task = Task {
                do {
                    for try await response in stream {
                        if Task.isCancelled { break }
                        let chunk = CompletionStreamDataChunk(
                            object: "",
                            model: model.info.modelName,
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
}

