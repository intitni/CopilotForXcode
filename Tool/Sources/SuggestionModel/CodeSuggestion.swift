import Foundation

public struct CodeSuggestion: Codable, Equatable {
    public init(
        id: String,
        text: String,
        position: CursorPosition,
        range: CursorRange
    ) {
        self.text = text
        self.position = position
        self.id = id
        self.range = range
    }

    /// The new code to be inserted and the original code on the first line.
    public var text: String
    /// The position of the cursor before generating the completion.
    public var position: CursorPosition
    /// An id.
    public var id: String
    /// The range of the original code that should be replaced.
    public var range: CursorRange
}
