import Foundation
import CodableWrappers

public struct EmbeddingModel: Codable, Equatable {
    public var id: String
    public var name: String
    @FallbackDecoding<EmptyEmbeddingModelFormat>
    public var format: Format
    @FallbackDecoding<EmptyEmbeddingModelInfo>
    public var info: Info

    public init(id: String, name: String, format: Format, info: Info) {
        self.id = id
        self.name = name
        self.format = format
        self.info = info
    }

    public enum Format: String, Codable, Equatable {
        case openAI
        case azureOpenAI
        case openAIFormat
    }

    public struct Info: Codable, Equatable {
        @FallbackDecoding<EmptyString>
        public var apiKeyName: String
        @FallbackDecoding<EmptyString>
        public var baseURL: String
        @FallbackDecoding<EmptyInt>
        public var maxTokens: Int
        @FallbackDecoding<EmptyString>
        public var modelName: String
        public var azureOpenAIDeploymentName: String {
            get { modelName }
            set { modelName = newValue }
        }

        public init(
            apiKeyName: String = "",
            baseURL: String = "",
            maxTokens: Int = 8192,
            modelName: String = ""
        ) {
            self.apiKeyName = apiKeyName
            self.baseURL = baseURL
            self.maxTokens = maxTokens
            self.modelName = modelName
        }
    }
    
    public var endpoint: String {
        switch format {
        case .openAI, .openAIFormat:
            let baseURL = info.baseURL
            if baseURL.isEmpty { return "https://api.openai.com/v1/embeddings" }
            return "\(baseURL)/v1/embeddings"
        case .azureOpenAI:
            let baseURL = info.baseURL
            let deployment = info.azureOpenAIDeploymentName
            let version = "2023-07-01-preview"
            if baseURL.isEmpty { return "" }
            return "\(baseURL)/openai/deployments/\(deployment)/embeddings?api-version=\(version)"
        }
    }
}


public struct EmptyEmbeddingModelInfo: FallbackValueProvider {
    public static var defaultValue: EmbeddingModel.Info { .init() }
}

public struct EmptyEmbeddingModelFormat: FallbackValueProvider {
    public static var defaultValue: EmbeddingModel.Format { .openAI }
}
