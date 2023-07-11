import CryptoKit
import Foundation

public struct CustomCommand: Codable, Equatable {
    /// The custom command feature.
    ///
    /// Keep everything optional so nothing will break when the format changes.
    public enum Feature: Codable, Equatable {
        /// Prompt to code.
        case promptToCode(
            extraSystemPrompt: String?,
            prompt: String?,
            continuousMode: Bool?,
            generateDescription: Bool?
        )
        /// Send message.
        case chatWithSelection(
            extraSystemPrompt: String?,
            prompt: String?,
            useExtraSystemPrompt: Bool?
        )
        /// Custom chat.
        case customChat(systemPrompt: String?, prompt: String?)
        /// Single round dialog.
        case singleRoundDialog(
            systemPrompt: String?,
            overwriteSystemPrompt: Bool?,
            prompt: String?,
            receiveReplyInNotification: Bool?
        )
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        commandId = try container.decodeIfPresent(String.self, forKey: .commandId)
        name = try container.decode(String.self, forKey: .name)
        feature = (try? container
            .decode(CustomCommand.Feature.self, forKey: .feature)) ?? .chatWithSelection(
                extraSystemPrompt: "",
                prompt: "",
                useExtraSystemPrompt: false
            )
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

