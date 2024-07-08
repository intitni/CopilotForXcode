import Foundation

public enum GoogleGenerativeAIModel: String {
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
        }
    }
}

extension GoogleGenerativeAIModel: CaseIterable {}

