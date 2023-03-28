import Foundation

public enum ChatGPTModel: String {
    case gpt35Turbo = "gpt-3.5-turbo"

    case gpt35Turbo0301 = "gpt-3.5-turbo-0301"

    case textDavinci003 = "text-davinci-003"

    case textCurie001 = "text-curie-001"

    case textBabbage001 = "text-babbage-001"

    case textAda001 = "text-ada-001"
}

public extension ChatGPTModel {
    var endpoint: String {
        switch self {
        case .gpt35Turbo:
            return "https://api.openai.com/v1/chat/completions"
        case .gpt35Turbo0301:
            return "https://api.openai.com/v1/chat/completions"
        case .textDavinci003:
            return "https://api.openai.com/v1/completions"
        case .textCurie001:
            return "https://api.openai.com/v1/completions"
        case .textBabbage001:
            return "https://api.openai.com/v1/completions"
        case .textAda001:
            return "https://api.openai.com/v1/completions"
        }
    }

    var maxToken: Int {
        switch self {
        case .gpt35Turbo:
            return 4096
        case .gpt35Turbo0301:
            return 4096
        case .textDavinci003:
            return 4097
        case .textCurie001:
            return 2049
        case .textBabbage001:
            return 2049
        case .textAda001:
            return 2049
        }
    }
}

extension ChatGPTModel: CaseIterable {}
