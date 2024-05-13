import Foundation
import CodableWrappers

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
        middlewareComments = []
    }

    public static func == (lhs: CodeSuggestion, rhs: CodeSuggestion) -> Bool {
        return lhs.text == rhs.text 
        && lhs.position == rhs.position
        && lhs.id == rhs.id
        && lhs.range == rhs.range
    }

    /// The new code to be inserted and the original code on the first line.
    public var text: String
    /// The position of the cursor before generating the completion.
    public var position: CursorPosition
    /// An id.
    public var id: String
    /// The range of the original code that should be replaced.
    public var range: CursorRange
    /// A place to store comments inserted by middleware for debugging use.
    @FallbackDecoding<EmptyArray> public var middlewareComments: [String]
}

