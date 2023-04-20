import Foundation

public struct CustomCommand: Codable {
    public enum Feature: Codable {
        case promptToCode(prompt: String, continuousMode: Bool)
        case chatWithSelection(prompt: String)
        case customChat(systemPrompt: String?, prompt: String)
    }
    
    public var name: String
    public var feature: Feature
}
