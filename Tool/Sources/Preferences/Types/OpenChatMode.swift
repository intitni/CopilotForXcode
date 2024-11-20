import Foundation

public enum OpenChatMode: Codable, Equatable, Identifiable, Hashable {
    public var id: String {
        switch self {
        case .chatPanel:
            return "chatPanel"
        case .browser:
            return "browser"
        case let .builtinExtension(extensionIdentifier, id, _):
            return "builtinExtension-\(extensionIdentifier)-\(id)"
        case let .externalExtension(extensionIdentifier, id, _):
            return "externalExtension-\(extensionIdentifier)-\(id)"
        }
    }

    public enum LegacyOpenChatMode: String {
        case chatPanel
        case browser
        case codeiumChat
    }

    case chatPanel
    case browser
    case builtinExtension(extensionIdentifier: String, id: String, tabName: String)
    case externalExtension(extensionIdentifier: String, id: String, tabName: String)
}

