import Foundation

public enum ChatGPTModel: String, CaseIterable {
    case gpt35Turbo = "gpt-3.5-turbo"
    case gpt35Turbo16k = "gpt-3.5-turbo-16k"
    case gpt4o = "gpt-4o"
    case gpt4oMini = "gpt-4o-mini"
    case gpt4 = "gpt-4"
    case gpt432k = "gpt-4-32k"
    case gpt4Turbo = "gpt-4-turbo"
    case gpt40314 = "gpt-4-0314"
    case gpt40613 = "gpt-4-0613"
    case gpt41106Preview = "gpt-4-1106-preview"
    case gpt4VisionPreview = "gpt-4-vision-preview"
    case gpt4TurboPreview = "gpt-4-turbo-preview"
    case gpt4Turbo20240409 = "gpt-4-turbo-2024-04-09"
    case gpt35Turbo1106 = "gpt-3.5-turbo-1106"
    case gpt35Turbo0125 = "gpt-3.5-turbo-0125"
    case gpt432k0314 = "gpt-4-32k-0314"
    case gpt432k0613 = "gpt-4-32k-0613"
    case gpt40125 = "gpt-4-0125-preview"
    case o1Preview = "o1-preview"
    case o1Preview20240912 = "o1-preview-2024-09-12"
    case o1Mini = "o1-mini"
    case o1Mini20240912 = "o1-mini-2024-09-12"
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
            return 16385
        case .gpt35Turbo1106:
            return 16385
        case .gpt35Turbo0125:
            return 16385
        case .gpt35Turbo16k:
            return 16385
        case .gpt40613:
            return 8192
        case .gpt432k0613:
            return 32768
        case .gpt41106Preview:
            return 128_000
        case .gpt4VisionPreview:
            return 128_000
        case .gpt4TurboPreview:
            return 128_000
        case .gpt40125:
            return 128_000
        case .gpt4Turbo:
            return 128_000
        case .gpt4Turbo20240409:
            return 128_000
        case .gpt4o:
            return 128_000
        case .gpt4oMini:
            return 128_000
        case .o1Preview, .o1Preview20240912:
            return 128_000
        case .o1Mini, .o1Mini20240912:
            return 128_000
        }
    }

    var supportsImages: Bool {
        switch self {
        case .gpt4VisionPreview, .gpt4Turbo, .gpt4Turbo20240409, .gpt4o, .gpt4oMini, .o1Preview,
             .o1Preview20240912, .o1Mini, .o1Mini20240912:
            return true
        default:
            return false
        }
    }
}

