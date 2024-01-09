import Foundation

public enum GoogleGenerativeAIModel: String {
    case geminiPro = "gemini-pro"
}

public extension GoogleGenerativeAIModel {
    var maxToken: Int {
        switch self {
        case .geminiPro:
            return 32768
        }
    }
}

extension GoogleGenerativeAIModel: CaseIterable {}

