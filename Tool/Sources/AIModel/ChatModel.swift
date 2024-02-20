import CodableWrappers
import Foundation

public struct ChatModel: Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    @FallbackDecoding<EmptyChatModelFormat>
    public var format: Format
    @FallbackDecoding<EmptyChatModelInfo>
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
        case googleAI
    }

    public struct Info: Codable, Equatable {
        @FallbackDecoding<EmptyString>
        public var apiKeyName: String
        @FallbackDecoding<EmptyString>
        public var baseURL: String
        @FallbackDecoding<EmptyBool>
        public var isFullURL: Bool
        @FallbackDecoding<EmptyInt>
        public var maxTokens: Int
        @FallbackDecoding<EmptyBool>
        public var supportsFunctionCalling: Bool
        @FallbackDecoding<EmptyBool>
        public var supportsOpenAIAPI2023_11: Bool
        @FallbackDecoding<EmptyString>
        public var modelName: String
        public var azureOpenAIDeploymentName: String {
            get { modelName }
            set { modelName = newValue }
        }

        public init(
            apiKeyName: String = "",
            baseURL: String = "",
            isFullURL: Bool = false,
            maxTokens: Int = 4000,
            supportsFunctionCalling: Bool = true,
            supportsOpenAIAPI2023_11: Bool = false,
            modelName: String = ""
        ) {
            self.apiKeyName = apiKeyName
            self.baseURL = baseURL
            self.isFullURL = isFullURL
            self.maxTokens = maxTokens
            self.supportsFunctionCalling = supportsFunctionCalling
            self.supportsOpenAIAPI2023_11 = supportsOpenAIAPI2023_11
            self.modelName = modelName
        }
    }

    public var endpoint: String {
        switch format {
        case .openAI:
            let baseURL = info.baseURL
            if baseURL.isEmpty { return "https://api.openai.com/v1/chat/completions" }
            return "\(baseURL)/v1/chat/completions"
        case .openAICompatible:
            let baseURL = info.baseURL
            if baseURL.isEmpty { return "https://api.openai.com/v1/chat/completions" }
            if info.isFullURL { return baseURL }
            return "\(baseURL)/v1/chat/completions"
        case .azureOpenAI:
            let baseURL = info.baseURL
            let deployment = info.azureOpenAIDeploymentName
            let version = "2024-02-15-preview"
            if baseURL.isEmpty { return "" }
            return "\(baseURL)/openai/deployments/\(deployment)/chat/completions?api-version=\(version)"
        case .googleAI:
            let baseURL = info.baseURL
            if baseURL.isEmpty { return "https://generativelanguage.googleapis.com/v1" }
            return "\(baseURL)/v1/chat/completions"
        }
    }
}

public struct EmptyChatModelInfo: FallbackValueProvider {
    public static var defaultValue: ChatModel.Info { .init() }
}

public struct EmptyChatModelFormat: FallbackValueProvider {
    public static var defaultValue: ChatModel.Format { .openAI }
}

