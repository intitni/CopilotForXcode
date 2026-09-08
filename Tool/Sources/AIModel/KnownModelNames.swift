import Foundation

/// Display names for custom-suggestion model dropdowns. Not a live provider catalog.
public enum KnownChatCompletionModels: String, CaseIterable {
    case gpt55 = "gpt-5.5"
    case gpt54 = "gpt-5.4"
    case gpt41 = "gpt-4.1"
    case gpt41Mini = "gpt-4.1-mini"
    case gpt41Nano = "gpt-4.1-nano"
    case gpt4o = "gpt-4o"
    case gpt4oMini = "gpt-4o-mini"
    case gpt4Turbo = "gpt-4-turbo"
    case gpt4 = "gpt-4"
    case o3 = "o3"
    case o3Mini = "o3-mini"
    case o4Mini = "o4-mini"
    case o1 = "o1"
    case o1Pro = "o1-pro"
    case o1Preview = "o1-preview"
    case gpt35Turbo = "gpt-3.5-turbo"

    public var maxToken: Int {
        switch self {
        case .gpt55, .gpt54, .gpt41, .gpt41Mini, .gpt41Nano:
            return 1_047_576
        case .gpt4o, .gpt4oMini, .gpt4Turbo:
            return 128_000
        case .gpt4:
            return 8192
        case .o3, .o3Mini, .o4Mini, .o1, .o1Pro:
            return 200_000
        case .o1Preview:
            return 128_000
        case .gpt35Turbo:
            return 16385
        }
    }
}

/// Completions-endpoint names (`/v1/completions`), not chat completions.
public enum KnownCompletionModels: String, CaseIterable {
    case gpt35TurboInstruct = "gpt-3.5-turbo-instruct"

    public var maxToken: Int {
        switch self {
        case .gpt35TurboInstruct:
            return 4096
        }
    }
}

public enum KnownGeminiModels: String, CaseIterable {
    case gemini25FlashPreview = "gemini-2.5-flash-preview-04-17"
    case gemini25ProPreview = "gemini-2.5-pro-preview-05-06"
    case gemini20Flash = "gemini-2.0-flash"
    case gemini20FlashLite = "gemini-2.0-flash-lite"
    case gemini15Pro = "gemini-1.5-pro"
    case gemini15Flash = "gemini-1.5-flash"
    case geminiPro = "gemini-pro"

    public var maxToken: Int {
        switch self {
        case .geminiPro:
            return 32768
        case .gemini15Pro:
            return 2_097_152
        case .gemini25FlashPreview, .gemini25ProPreview, .gemini20Flash, .gemini20FlashLite,
             .gemini15Flash:
            return 1_048_576
        }
    }
}
