import ChatBasic
import Foundation
import Logger

public struct EmbeddingService {
    public let configuration: EmbeddingConfiguration

    public init(configuration: EmbeddingConfiguration) {
        self.configuration = configuration
    }

    public func embed(text: String) async throws -> EmbeddingResponse {
        guard let model = configuration.model else {
            throw ChatGPTServiceError.embeddingModelNotAvailable
        }
        let embeddingResponse: EmbeddingResponse
        switch model.format {
        case .openAI, .openAICompatible, .azureOpenAI:
            embeddingResponse = try await OpenAIEmbeddingService(
                apiKey: configuration.apiKey,
                model: model,
                endpoint: configuration.endpoint
            ).embed(text: text)
        case .ollama:
            embeddingResponse = try await OllamaEmbeddingService(
                model: model,
                endpoint: configuration.endpoint
            ).embed(text: text)
        }

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

    public func embed(text: [String]) async throws -> EmbeddingResponse {
        guard let model = configuration.model else {
            throw ChatGPTServiceError.embeddingModelNotAvailable
        }
        let embeddingResponse: EmbeddingResponse
        switch model.format {
        case .openAI, .openAICompatible, .azureOpenAI:
            embeddingResponse = try await OpenAIEmbeddingService(
                apiKey: configuration.apiKey,
                model: model,
                endpoint: configuration.endpoint
            ).embed(texts: text)
        case .ollama:
            embeddingResponse = try await OllamaEmbeddingService(
                model: model,
                endpoint: configuration.endpoint
            ).embed(texts: text)
        }

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
        guard let model = configuration.model else {
            throw ChatGPTServiceError.embeddingModelNotAvailable
        }
        let embeddingResponse: EmbeddingResponse
        switch model.format {
        case .openAI, .openAICompatible, .azureOpenAI:
            embeddingResponse = try await OpenAIEmbeddingService(
                apiKey: configuration.apiKey,
                model: model,
                endpoint: configuration.endpoint
            ).embed(tokens: tokens)
        case .ollama:
            embeddingResponse = try await OllamaEmbeddingService(
                model: model,
                endpoint: configuration.endpoint
            ).embed(tokens: tokens)
        }

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
}

