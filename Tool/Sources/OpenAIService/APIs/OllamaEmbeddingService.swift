import AIModel
import Foundation
import Logger

struct OllamaEmbeddingService: EmbeddingAPI {
    struct EmbeddingRequestBody: Encodable {
        var prompt: String
        var model: String
    }

    struct ResponseBody: Decodable {
        var embedding: [Float]
    }

    let model: EmbeddingModel
    let endpoint: String

    public func embed(text: String) async throws -> EmbeddingResponse {
        guard let url = URL(string: endpoint) else { throw ChatGPTServiceError.endpointIncorrect }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(EmbeddingRequestBody(
            prompt: text,
            model: model.info.modelName
        ))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (result, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw ChatGPTServiceError.responseInvalid
        }

        guard response.statusCode == 200 else {
            let error = try? JSONDecoder().decode(
                OpenAIChatCompletionsService.CompletionAPIError.self,
                from: result
            )
            throw error ?? ChatGPTServiceError
                .otherError(String(data: result, encoding: .utf8) ?? "Unknown Error")
        }

        let embeddingResponse = try JSONDecoder().decode(ResponseBody.self, from: result)
        #if DEBUG
        Logger.service.info("""
        Embedding usage
        - number of strings: 1
        - prompt tokens: N/A
        - total tokens: N/A

        """)
        #endif
        return .init(
            data: [.init(
                embedding: embeddingResponse.embedding,
                index: 0,
                object: model.info.modelName
            )],
            model: model.info.modelName,
            usage: .init(prompt_tokens: 0, total_tokens: 0)
        )
    }

    public func embed(texts: [String]) async throws -> EmbeddingResponse {
        try await withThrowingTaskGroup(of: EmbeddingResponse.self) { group in
            for text in texts {
                _ = group.addTaskUnlessCancelled {
                    try await self.embed(text: text)
                }
            }

            var result = EmbeddingResponse(
                data: [],
                model: model.info.modelName,
                usage: .init(prompt_tokens: 0, total_tokens: 0)
            )

            for try await response in group {
                result.data.append(contentsOf: response.data)
                result.usage.prompt_tokens += response.usage.prompt_tokens
                result.usage.total_tokens += response.usage.total_tokens
            }

            return result
        }
    }

    public func embed(tokens: [[Int]]) async throws -> EmbeddingResponse {
        throw CancellationError()
    }
}

