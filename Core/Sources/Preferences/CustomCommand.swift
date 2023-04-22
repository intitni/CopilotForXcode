import Foundation

public struct CustomCommand: Codable {
    /// The custom command feature.
    ///
    /// Keep everything optional so nothing will break when the format changes.
    public enum Feature: Codable {
        case promptToCode(extraSystemPrompt: String?, prompt: String?, continuousMode: Bool?)
        case chatWithSelection(extraSystemPrompt: String?, prompt: String?)
        case customChat(systemPrompt: String?, prompt: String?)
    }

    public var name: String
    public var feature: Feature
    
    public init(name: String, feature: Feature) {
        self.name = name
        self.feature = feature
    }
}
