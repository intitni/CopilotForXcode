import AppKit
import Foundation

public struct StorableFont: Codable, Equatable {
    public var nsFont: NSFont

    public init(nsFont: NSFont) {
        self.nsFont = nsFont
    }

    public enum CodingKeys: String, CodingKey {
        case nsFont
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fontData = try container.decode(Data.self, forKey: .nsFont)
        guard let nsFont = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: NSFont.self,
            from: fontData
        ) else {
            throw DecodingError.dataCorruptedError(
                forKey: .nsFont,
                in: container,
                debugDescription: "Failed to decode NSFont"
            )
        }
        self.nsFont = nsFont
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let fontData = try NSKeyedArchiver.archivedData(
            withRootObject: nsFont,
            requiringSecureCoding: false
        )
        try container.encode(fontData, forKey: .nsFont)
    }
}

