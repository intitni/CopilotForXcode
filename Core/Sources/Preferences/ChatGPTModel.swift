import Foundation

public enum ChatGPTModel: String {
    case gpt4 = "gpt-4"

    case gpt40314 = "gpt-4-0314"

    case gpt432k = "gpt-4-32k"

    case gpt432k0314 = "gpt-4-32k-0314"

    case gpt35Turbo = "gpt-3.5-turbo"

    case gpt35Turbo0301 = "gpt-3.5-turbo-0301"
}

public extension ChatGPTModel {
    var endpoint: String {
        "https://api.openai.com/v1/chat/completions"
    }

    var maxToken: Int {
        switch self {
        case .gpt4:
            return 8192
        case .gpt40314:
            return 8192
        case .gpt432k:
            return 32768
        case .gpt432k0314:
            return 32768
        case .gpt35Turbo:
            return 4096
        case .gpt35Turbo0301:
            return 4096
        }
    }
}

extension ChatGPTModel: CaseIterable {}
