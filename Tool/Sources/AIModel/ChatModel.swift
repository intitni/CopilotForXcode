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
        case ollama
        case claude
        case gitHubCopilot
    }

    public struct Info: Codable, Equatable {
        public struct OllamaInfo: Codable, Equatable {
            @FallbackDecoding<EmptyString>
            public var keepAlive: String

            public init(keepAlive: String = "") {
                self.keepAlive = keepAlive
            }
        }

        public struct OpenAIInfo: Codable, Equatable {
            @FallbackDecoding<EmptyString>
            public var organizationID: String
            @FallbackDecoding<EmptyString>
            public var projectID: String

            public init(organizationID: String = "", projectID: String = "") {
                self.organizationID = organizationID
                self.projectID = projectID
            }
        }

        public struct OpenAICompatibleInfo: Codable, Equatable {
            @FallbackDecoding<EmptyBool>
            public var enforceMessageOrder: Bool
            @FallbackDecoding<EmptyTrue>
            public var supportsMultipartMessageContent: Bool
            @FallbackDecoding<EmptyBool>
            public var requiresBeginWithUserMessage: Bool

            public init(
                enforceMessageOrder: Bool = false,
                supportsMultipartMessageContent: Bool = true,
                requiresBeginWithUserMessage: Bool = false
            ) {
                self.enforceMessageOrder = enforceMessageOrder
                self.supportsMultipartMessageContent = supportsMultipartMessageContent
                self.requiresBeginWithUserMessage = requiresBeginWithUserMessage
            }
        }

        public struct GoogleGenerativeAIInfo: Codable, Equatable {
            @FallbackDecoding<EmptyString>
            public var apiVersion: String

            public init(apiVersion: String = "") {
                self.apiVersion = apiVersion
            }
        }

        public struct CustomHeaderInfo: Codable, Equatable {
            public struct HeaderField: Codable, Equatable {
                public var key: String
                public var value: String

                public init(key: String, value: String) {
                    self.key = key
                    self.value = value
                }
            }

            @FallbackDecoding<EmptyArray>
            public var headers: [HeaderField]

            public init(headers: [HeaderField] = []) {
                self.headers = headers
            }
        }
        
        public struct CustomBodyInfo: Codable, Equatable {
            public var jsonBody: String
            
            public init(jsonBody: String = "") {
                self.jsonBody = jsonBody
            }
        }

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
        public var supportsImage: Bool
        @FallbackDecoding<EmptyBool>
        public var supportsAudio: Bool
        @FallbackDecoding<EmptyString>
        public var modelName: String

        @FallbackDecoding<EmptyChatModelOpenAIInfo>
        public var openAIInfo: OpenAIInfo
        @FallbackDecoding<EmptyChatModelOllamaInfo>
        public var ollamaInfo: OllamaInfo
        @FallbackDecoding<EmptyChatModelGoogleGenerativeAIInfo>
        public var googleGenerativeAIInfo: GoogleGenerativeAIInfo
        @FallbackDecoding<EmptyChatModelOpenAICompatibleInfo>
        public var openAICompatibleInfo: OpenAICompatibleInfo
        @FallbackDecoding<EmptyChatModelCustomHeaderInfo>
        public var customHeaderInfo: CustomHeaderInfo
        @FallbackDecoding<EmptyChatModelCustomBodyInfo>
        public var customBodyInfo: CustomBodyInfo

        public init(
            apiKeyName: String = "",
            baseURL: String = "",
            isFullURL: Bool = false,
            maxTokens: Int = 4000,
            supportsFunctionCalling: Bool = true,
            supportsImage: Bool = false,
            supportsAudio: Bool = false,
            modelName: String = "",
            openAIInfo: OpenAIInfo = OpenAIInfo(),
            ollamaInfo: OllamaInfo = OllamaInfo(),
            googleGenerativeAIInfo: GoogleGenerativeAIInfo = GoogleGenerativeAIInfo(),
            openAICompatibleInfo: OpenAICompatibleInfo = OpenAICompatibleInfo(),
            customHeaderInfo: CustomHeaderInfo = CustomHeaderInfo(),
            customBodyInfo: CustomBodyInfo = CustomBodyInfo()
        ) {
            self.apiKeyName = apiKeyName
            self.baseURL = baseURL
            self.isFullURL = isFullURL
            self.maxTokens = maxTokens
            self.supportsFunctionCalling = supportsFunctionCalling
            self.supportsImage = supportsImage
            self.supportsAudio = supportsAudio
            self.modelName = modelName
            self.openAIInfo = openAIInfo
            self.ollamaInfo = ollamaInfo
            self.googleGenerativeAIInfo = googleGenerativeAIInfo
            self.openAICompatibleInfo = openAICompatibleInfo
            self.customHeaderInfo = customHeaderInfo
            self.customBodyInfo = customBodyInfo
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
            let deployment = info.modelName
            let version = "2024-02-15-preview"
            if baseURL.isEmpty { return "" }
            return "\(baseURL)/openai/deployments/\(deployment)/chat/completions?api-version=\(version)"
        case .googleAI:
            let baseURL = info.baseURL
            if baseURL.isEmpty { return "https://generativelanguage.googleapis.com" }
            return "\(baseURL)"
        case .ollama:
            let baseURL = info.baseURL
            if baseURL.isEmpty { return "http://localhost:11434/api/chat" }
            return "\(baseURL)/api/chat"
        case .claude:
            let baseURL = info.baseURL
            if baseURL.isEmpty { return "https://api.anthropic.com/v1/messages" }
            return "\(baseURL)/v1/messages"
        case .gitHubCopilot:
            return "https://api.githubcopilot.com/chat/completions"
        }
    }
}

public struct EmptyChatModelInfo: FallbackValueProvider {
    public static var defaultValue: ChatModel.Info { .init() }
}

public struct EmptyChatModelFormat: FallbackValueProvider {
    public static var defaultValue: ChatModel.Format { .openAI }
}

public struct EmptyChatModelOllamaInfo: FallbackValueProvider {
    public static var defaultValue: ChatModel.Info.OllamaInfo { .init() }
}

public struct EmptyChatModelOpenAIInfo: FallbackValueProvider {
    public static var defaultValue: ChatModel.Info.OpenAIInfo { .init() }
}

public struct EmptyChatModelGoogleGenerativeAIInfo: FallbackValueProvider {
    public static var defaultValue: ChatModel.Info.GoogleGenerativeAIInfo { .init() }
}

public struct EmptyChatModelOpenAICompatibleInfo: FallbackValueProvider {
    public static var defaultValue: ChatModel.Info.OpenAICompatibleInfo { .init() }
}

public struct EmptyChatModelCustomHeaderInfo: FallbackValueProvider {
    public static var defaultValue: ChatModel.Info.CustomHeaderInfo { .init() }
}

public struct EmptyChatModelCustomBodyInfo: FallbackValueProvider {
    public static var defaultValue: ChatModel.Info.CustomBodyInfo { .init() }
}

public struct EmptyTrue: FallbackValueProvider {
    public static var defaultValue: Bool { true }
}
