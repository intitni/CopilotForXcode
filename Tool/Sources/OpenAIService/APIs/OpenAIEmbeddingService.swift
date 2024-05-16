import AIModel
import Foundation
import Logger

struct OpenAIEmbeddingService: EmbeddingAPI {
    struct EmbeddingRequestBody: Encodable {
        var input: [String]
        var model: String
    }

    struct EmbeddingFromTokensRequestBody: Encodable {
        var input: [[Int]]
        var model: String
    }

    let apiKey: String
    let model: EmbeddingModel
    let endpoint: String

    public func embed(text: String) async throws -> EmbeddingResponse {
        return try await embed(texts: [text])
    }

    public func embed(texts text: [String]) async throws -> EmbeddingResponse {
        guard let url = URL(string: endpoint) else { throw ChatGPTServiceError.endpointIncorrect }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(EmbeddingRequestBody(
            input: text,
            model: model.info.modelName
        ))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        Self.setupAppInformation(&request)
        Self.setupAPIKey(&request, model: model, apiKey: apiKey)

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

        let embeddingResponse = try JSONDecoder().decode(EmbeddingResponse.self, from: result)
        #if DEBUG
        Logger.service.info("""
        Embedding usage
        - number of strings: \(text.count)
        - prompt tokens: \(embeddingResponse.usage.prompt_tokens)
        - total tokens: \(embeddingResponse.usage.total_tokens)

        """)
        #endif
        return embeddingResponse
    }

    public func embed(tokens: [[Int]]) async throws -> EmbeddingResponse {
        guard let url = URL(string: endpoint) else { throw ChatGPTServiceError.endpointIncorrect }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(EmbeddingFromTokensRequestBody(
            input: tokens,
            model: model.info.modelName
        ))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        Self.setupAppInformation(&request)
        Self.setupAPIKey(&request, model: model, apiKey: apiKey)

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

        let embeddingResponse = try JSONDecoder().decode(EmbeddingResponse.self, from: result)
        #if DEBUG
        Logger.service.info("""
        Embedding usage
        - number of strings: \(tokens.count)
        - prompt tokens: \(embeddingResponse.usage.prompt_tokens)
        - total tokens: \(embeddingResponse.usage.total_tokens)

        """)
        #endif
        return embeddingResponse
    }

    static func setupAppInformation(_ request: inout URLRequest) {
        if #available(macOS 13.0, *) {
            if request.url?.host == "openrouter.ai" {
                request.setValue("Copilot for Xcode", forHTTPHeaderField: "X-Title")
                request.setValue(
                    "https://github.com/intitni/CopilotForXcode",
                    forHTTPHeaderField: "HTTP-Referer"
                )
            }
        } else {
            if request.url?.host == "openrouter.ai" {
                request.setValue("Copilot for Xcode", forHTTPHeaderField: "X-Title")
                request.setValue(
                    "https://github.com/intitni/CopilotForXcode",
                    forHTTPHeaderField: "HTTP-Referer"
                )
            }
        }
    }

    static func setupAPIKey(_ request: inout URLRequest, model: EmbeddingModel, apiKey: String) {
        if !apiKey.isEmpty {
            switch model.format {
            case .openAI:
                if model.info.openAIInfo.organizationID.isEmpty {
                    request.setValue(
                        model.info.openAIInfo.organizationID,
                        forHTTPHeaderField: "OpenAI-Organization"
                    )
                }
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            case .openAICompatible:
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            case .azureOpenAI:
                request.setValue(apiKey, forHTTPHeaderField: "api-key")
            case .ollama:
                assertionFailure("Unsupported")
            }
        }
    }
}

