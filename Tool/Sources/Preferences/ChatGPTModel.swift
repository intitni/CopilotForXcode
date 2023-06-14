import Foundation

public enum ChatGPTModel: String {
    case gpt35Turbo = "gpt-3.5-turbo"
    case gpt35Turbo16k = "gpt-3.5-turbo-16k"
    case gpt4 = "gpt-4"
    case gpt432k = "gpt-4-32k"
    case gpt40314 = "gpt-4-0314"
    case gpt40613 = "gpt-4-0613"
    case gpt35Turbo0301 = "gpt-3.5-turbo-0301"
    case gpt35Turbo0613 = "gpt-3.5-turbo-0613"
    case gpt35Turbo16k0613 = "gpt-3.5-turbo-16k-0613"
    case gpt432k0314 = "gpt-4-32k-0314"
    case gpt432k0613 = "gpt-4-32k-0613"
}

public extension ChatGPTModel {
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
        case .gpt35Turbo0613:
            return 4096
        case .gpt35Turbo16k:
            return 16384
        case .gpt35Turbo16k0613:
            return 16384
        case .gpt40613:
            return 8192
        case .gpt432k0613:
            return 32768
        }
    }
}

extension ChatGPTModel: CaseIterable {}
