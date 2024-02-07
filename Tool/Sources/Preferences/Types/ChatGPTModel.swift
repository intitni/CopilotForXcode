import Foundation

public enum ChatGPTModel: String {
    case gpt35Turbo = "gpt-3.5-turbo"
    case gpt35Turbo16k = "gpt-3.5-turbo-16k"
    case gpt4 = "gpt-4"
    case gpt432k = "gpt-4-32k"
    case gpt4TurboPreview = "gpt-4-turbo-preview"
    case gpt40314 = "gpt-4-0314"
    case gpt40613 = "gpt-4-0613"
    case gpt41106Preview = "gpt-4-1106-preview"
    case gpt4VisionPreview = "gpt-4-vision-preview"
    case gpt35Turbo0301 = "gpt-3.5-turbo-0301"
    case gpt35Turbo0613 = "gpt-3.5-turbo-0613"
    case gpt35Turbo1106 = "gpt-3.5-turbo-1106"
    case gpt35Turbo0125 = "gpt-3.5-turbo-0125"
    case gpt35Turbo16k0613 = "gpt-3.5-turbo-16k-0613"
    case gpt432k0314 = "gpt-4-32k-0314"
    case gpt432k0613 = "gpt-4-32k-0613"
    case gpt40125 = "gpt-4-0125-preview"
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
        case .gpt35Turbo1106:
            return 16385
        case .gpt35Turbo0125:
            return 16385
        case .gpt35Turbo16k:
            return 16385
        case .gpt35Turbo16k0613:
            return 16385
        case .gpt40613:
            return 8192
        case .gpt432k0613:
            return 32768
        case .gpt41106Preview:
            return 128000
        case .gpt4VisionPreview:
            return 128000
        case .gpt4TurboPreview:
            return 128000
        case .gpt40125:
            return 128000
        }
    }
    
    var supportsImages: Bool {
        switch self {
        case .gpt4VisionPreview:
            return true
        default:
            return false
        }
    }
}

extension ChatGPTModel: CaseIterable {}
