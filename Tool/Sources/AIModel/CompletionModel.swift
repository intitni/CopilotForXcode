import CodableWrappers
import Foundation

/// A completion model.
public struct CompletionModel: Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    @FallbackDecoding<EmptyCompletionModelFormat>
    public var format: Format
    @FallbackDecoding<EmptyCompletionModelInfo>
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

        case unknown
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
            maxTokens: Int = 4000,
            modelName: String = "",
            openAIInfo: OpenAIInfo = OpenAIInfo(),
            ollamaInfo: OllamaInfo = OllamaInfo()
        ) {
            self.apiKeyName = apiKeyName
            self.baseURL = baseURL
            self.isFullURL = isFullURL
            self.maxTokens = maxTokens
            self.modelName = modelName
            self.openAIInfo = openAIInfo
            self.ollamaInfo = ollamaInfo
        }
    }

    public var endpoint: String {
        switch format {
        case .openAI:
            let baseURL = info.baseURL
            if baseURL.isEmpty { return "https://api.openai.com/v1/completions" }
            return "\(baseURL)/v1/completions"
        case .openAICompatible:
            let baseURL = info.baseURL
            if baseURL.isEmpty { return "https://api.openai.com/v1/completions" }
            if info.isFullURL { return baseURL }
            return "\(baseURL)/v1/completions"
        case .azureOpenAI:
            let baseURL = info.baseURL
            let deployment = info.modelName
            let version = "2023-07-01-preview"
            if baseURL.isEmpty { return "" }
            return "\(baseURL)/openai/deployments/\(deployment)/completions?api-version=\(version)"
        case .ollama:
            let baseURL = info.baseURL
            if baseURL.isEmpty { return "http://localhost:11434/api/generate" }
            return "\(baseURL)/api/generate"
        case .unknown:
            return ""
        }
    }
}

public struct EmptyCompletionModelInfo: FallbackValueProvider {
    public static var defaultValue: CompletionModel.Info { .init() }
}

public struct EmptyCompletionModelFormat: FallbackValueProvider {
    public static var defaultValue: CompletionModel.Format { .unknown }
}

