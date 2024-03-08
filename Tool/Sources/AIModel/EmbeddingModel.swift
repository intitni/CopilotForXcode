import CodableWrappers
import Foundation

public struct EmbeddingModel: Codable, Equatable, Identifiable {
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

    public enum Format: String, Codable, Equatable, CaseIterable {
        case openAI
        case azureOpenAI
        case openAICompatible
        case ollama
    }

    public struct Info: Codable, Equatable {
        public typealias OllamaInfo = ChatModel.Info.OllamaInfo
        public typealias OpenAIInfo = ChatModel.Info.OpenAIInfo

        @FallbackDecoding<EmptyString>
        public var apiKeyName: String
        @FallbackDecoding<EmptyString>
        public var baseURL: String
        @FallbackDecoding<EmptyBool>
        public var isFullURL: Bool
        @FallbackDecoding<EmptyInt>
        public var maxTokens: Int
        @FallbackDecoding<EmptyInt>
        public var dimensions: Int
        @FallbackDecoding<EmptyString>
        public var modelName: String

        @FallbackDecoding<EmptyChatModelOpenAIInfo>
        public var openAIInfo: OpenAIInfo
        @FallbackDecoding<EmptyChatModelOllamaInfo>
        public var ollamaInfo: OllamaInfo

        public init(
            apiKeyName: String = "",
            baseURL: String = "",
            isFullURL: Bool = false,
            maxTokens: Int = 8192,
            dimensions: Int = 1536,
            modelName: String = "",
            openAIInfo: OpenAIInfo = OpenAIInfo(),
            ollamaInfo: OllamaInfo = OllamaInfo()
        ) {
            self.apiKeyName = apiKeyName
            self.baseURL = baseURL
            self.isFullURL = isFullURL
            self.maxTokens = maxTokens
            self.dimensions = dimensions
            self.modelName = modelName
            self.openAIInfo = openAIInfo
            self.ollamaInfo = ollamaInfo
        }
    }

    public var endpoint: String {
        switch format {
        case .openAI:
            let baseURL = info.baseURL
            if baseURL.isEmpty { return "https://api.openai.com/v1/embeddings" }
            return "\(baseURL)/v1/embeddings"
        case .openAICompatible:
            let baseURL = info.baseURL
            if baseURL.isEmpty { return "https://api.openai.com/v1/embeddings" }
            if info.isFullURL { return baseURL }
            return "\(baseURL)/v1/embeddings"
        case .azureOpenAI:
            let baseURL = info.baseURL
            let deployment = info.modelName
            let version = "2024-02-15-preview"
            if baseURL.isEmpty { return "" }
            return "\(baseURL)/openai/deployments/\(deployment)/embeddings?api-version=\(version)"
        case .ollama:
            let baseURL = info.baseURL
            if baseURL.isEmpty { return "http://localhost:11434/api/embeddings" }
            return "\(baseURL)/api/embeddings"
        }
    }
}

public struct EmptyEmbeddingModelInfo: FallbackValueProvider {
    public static var defaultValue: EmbeddingModel.Info { .init() }
}

public struct EmptyEmbeddingModelFormat: FallbackValueProvider {
    public static var defaultValue: EmbeddingModel.Format { .openAI }
}

