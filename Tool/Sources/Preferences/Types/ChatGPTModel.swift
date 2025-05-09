import Foundation

public enum ChatGPTModel: String, CaseIterable {
    case gpt35Turbo = "gpt-3.5-turbo"
    case gpt35Turbo16k = "gpt-3.5-turbo-16k"
    case gpt4o = "gpt-4o"
    case gpt4oMini = "gpt-4o-mini"
    case gpt4 = "gpt-4"
    case gpt432k = "gpt-4-32k"
    case gpt4Turbo = "gpt-4-turbo"
    case gpt4VisionPreview = "gpt-4-vision-preview"
    case gpt432k0314 = "gpt-4-32k-0314"
    case gpt432k0613 = "gpt-4-32k-0613"
    case gpt40125 = "gpt-4-0125-preview"
    case gpt4_1 = "gpt-4.1"
    case gpt4_1Mini = "gpt-4.1-mini"
    case gpt4_1Nano = "gpt-4.1-nano"
    case o1 = "o1"
    case o1Preview = "o1-preview"
    case o1Pro = "o1-pro"
    case o3Mini = "o3-mini"
    case o3 = "o3"
    case o4Mini = "o4-mini"
}

public extension ChatGPTModel {
    var maxToken: Int {
        switch self {
        case .gpt4:
            return 8192
        case .gpt432k:
            return 32768
        case .gpt432k0314:
            return 32768
        case .gpt35Turbo:
            return 16385
        case .gpt35Turbo16k:
            return 16385
        case .gpt432k0613:
            return 32768
        case .gpt4VisionPreview:
            return 128_000
        case .gpt40125:
            return 128_000
        case .gpt4Turbo:
            return 128_000
        case .gpt4o:
            return 128_000
        case .gpt4oMini:
            return 128_000
        case .o1Preview:
            return 128_000
        case .o1:
            return 200_000
        case .o3Mini:
            return 200_000
        case .gpt4_1:
            return 1_047_576
        case .gpt4_1Mini:
            return 1_047_576
        case .gpt4_1Nano:
            return 1_047_576
        case .o1Pro:
            return 200_000
        case .o3:
            return 200_000
        case .o4Mini:
            return 200_000
        }
    }

    var supportsImages: Bool {
        switch self {
        case .gpt4VisionPreview, .gpt4Turbo, .gpt4o, .gpt4oMini, .o1Preview, .o1, .o3Mini:
            return true
        default:
            return false
        }
    }
    
    var supportsTemperature: Bool {
        switch self {
        case .o1Preview, .o1, .o3Mini:
            return false
        default:
            return true
        }
    }
    
    var supportsSystemPrompt: Bool {
        switch self {
        case .o1Preview, .o1, .o3Mini:
            return false
        default:
            return true
        }
    }
}

