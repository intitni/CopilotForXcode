import Foundation

public struct CopilotCompletion: Codable {
    public init(
        text: String,
        position: CursorPosition,
        uuid: String,
        range: CursorRange,
        displayText: String
    ) {
        self.text = text
        self.position = position
        self.uuid = uuid
        self.range = range
        self.displayText = displayText
    }

    public var text: String
    public var position: CursorPosition
    public var uuid: String
    public var range: CursorRange
    public var displayText: String
}
