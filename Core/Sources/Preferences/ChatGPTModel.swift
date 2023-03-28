import Foundation

public enum ChatGPTModel: String {
    case gpt35Turbo = "gpt-3.5-turbo"

    case gpt35Turbo0301 = "gpt-3.5-turbo-0301"
}

public extension ChatGPTModel {
    var endpoint: String {
        switch self {
        case .gpt35Turbo:
            return "https://api.openai.com/v1/chat/completions"
        case .gpt35Turbo0301:
            return "https://api.openai.com/v1/chat/completions"
        }
    }

    var maxToken: Int {
        switch self {
        case .gpt35Turbo:
            return 2049
        case .gpt35Turbo0301:
            return 2049
        }
    }
}

extension ChatGPTModel: CaseIterable {}
