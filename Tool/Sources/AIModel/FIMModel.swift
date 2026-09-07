import CodableWrappers
import Foundation

/// A completion model.
public struct FIMModel: Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    @FallbackDecoding<EmptyFIMModelFormat>
    public var format: Format
    @FallbackDecoding<EmptyFIMModelInfo>
    public var info: Info

    public init(id: String, name: String, format: Format, info: Info) {
        self.id = id
        self.name = name
        self.format = format
        self.info = info
    }

    public enum Format: String, Codable, Equatable, CaseIterable {
        case mistral
        case ollama
        case ollamaCompatible
        
        case unknown
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
        @FallbackDecoding<EmptyString>
        public var modelName: String
        @FallbackDecoding<EmptyFIMModelAuthenticationMode>
        public var authenticationMode: AuthenticationMode
        @FallbackDecoding<EmptyString>
        public var authenticationHeaderFieldName: String
        
        public enum AuthenticationMode: Codable, Equatable, CaseIterable {
            case header
            case bearerToken
        }
        
        @FallbackDecoding<EmptyChatModelOllamaInfo>
        public var ollamaInfo: ChatModel.Info.OllamaInfo

        public init(
            apiKeyName: String = "",
            baseURL: String = "",
            isFullURL: Bool = false,
            maxTokens: Int = 4000,
            modelName: String = "",
            authenticationMode: AuthenticationMode = .bearerToken,
            authenticationHeaderFieldName: String = "",
            ollamaInfo: ChatModel.Info.OllamaInfo = ChatModel.Info.OllamaInfo()
        ) {
            self.apiKeyName = apiKeyName
            self.baseURL = baseURL
            self.isFullURL = isFullURL
            self.maxTokens = maxTokens
            self.modelName = modelName
            self.ollamaInfo = ollamaInfo
            self.authenticationMode = authenticationMode
            self.authenticationHeaderFieldName = authenticationHeaderFieldName
        }
    }

    public var endpoint: String {
        switch format {
        case .mistral:
            let baseURL = info.baseURL
            if baseURL.isEmpty { return "https://api.mistral.ai/v1/fim/completions" }
            if info.isFullURL { return baseURL }
            return "\(baseURL)/v1/fim/completions"
        case .ollama:
            let baseURL = info.baseURL
            if baseURL.isEmpty { return "http://localhost:11434/api/generate" }
            return "\(baseURL)/api/generate"
        case .ollamaCompatible:
            let baseURL = info.baseURL
            if baseURL.isEmpty { return "http://localhost:11434/api/generate" }
            if info.isFullURL { return baseURL }
            return "\(baseURL)/api/generate"
        case .unknown:
            return ""
        }
    }
}

public struct EmptyFIMModelInfo: FallbackValueProvider {
    public static var defaultValue: FIMModel.Info { .init() }
}

public struct EmptyFIMModelFormat: FallbackValueProvider {
    public static var defaultValue: FIMModel.Format { .unknown }
}

public struct EmptyFIMModelAuthenticationMode: FallbackValueProvider {
    public static var defaultValue: FIMModel.Info.AuthenticationMode { .bearerToken }
}
