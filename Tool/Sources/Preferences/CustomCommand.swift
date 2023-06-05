import Foundation
import CryptoKit

public struct CustomCommand: Codable {
    /// The custom command feature.
    ///
    /// Keep everything optional so nothing will break when the format changes.
    public enum Feature: Codable {
        case promptToCode(extraSystemPrompt: String?, prompt: String?, continuousMode: Bool?, generateDescription: Bool?)
        case chatWithSelection(extraSystemPrompt: String?, prompt: String?, useExtraSystemPrompt: Bool?)
        case customChat(systemPrompt: String?, prompt: String?)
    }

    public var id: String { commandId ?? legacyId }
    public var commandId: String?
    public var name: String
    public var feature: Feature
    
    public init(commandId: String, name: String, feature: Feature) {
        self.commandId = commandId
        self.name = name
        self.feature = feature
    }
    
    var legacyId: String {
        name.sha1HexString
    }
}

private extension Digest {
    var bytes: [UInt8] { Array(makeIterator()) }
    var data: Data { Data(bytes) }

    var hexStr: String {
        bytes.map { String(format: "%02X", $0) }.joined()
    }
}

private extension String {
    var sha1HexString: String {
        Insecure.SHA1.hash(data: data(using: .utf8) ?? Data()).hexStr
    }
}
