import Foundation

public enum OpenChatMode: Codable, Equatable {
    public enum LegacyOpenChatMode: String {
        case chatPanel
        case browser
        case codeiumChat
    }
    
    case chatPanel
    case browser
    case builtinExtension(extensionIdentifier: String, tabName: String)
    case externalExtension(extensionIdentifier: String, tabName: String)
}
