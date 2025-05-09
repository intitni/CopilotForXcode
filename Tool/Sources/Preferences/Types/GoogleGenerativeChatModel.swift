import Foundation

public enum GoogleGenerativeAIModel: String {
    case gemini25FlashPreview = "gemini-2.5-flash-preview-04-17"
    case gemini25ProPreview = "gemini-2.5-pro-preview-05-06"
    case gemini20Flash = "gemini-2.0-flash"
    case gemini20FlashLite = "gemini-2.0-flash-lite"
    case gemini15Pro = "gemini-1.5-pro"
    case gemini15Flash = "gemini-1.5-flash"
    case geminiPro = "gemini-pro"
}

public extension GoogleGenerativeAIModel {
    var maxToken: Int {
        switch self {
        case .geminiPro:
            return 32768
        case .gemini15Flash:
            return 1_048_576
        case .gemini15Pro:
            return 2_097_152
        case .gemini25FlashPreview:
            return 1_048_576
        case .gemini25ProPreview:
            return 1_048_576
        case .gemini20Flash:
            return 1_048_576
        case .gemini20FlashLite:
            return 1_048_576
        }
    }
}

extension GoogleGenerativeAIModel: CaseIterable {}

