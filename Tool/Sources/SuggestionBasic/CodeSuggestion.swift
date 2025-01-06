import CodableWrappers
import Foundation

public struct CodeSuggestion: Codable, Equatable, Identifiable {
    public struct Description: Codable, Equatable {
        public enum Kind: Codable, Equatable {
            case warning
            case action
        }
        
        public var kind: Kind
        public var content: String
        
        public init(kind: Kind, content: String) {
            self.kind = kind
            self.content = content
        }
    }
    
    public enum EffectiveRange: Codable, Equatable {
        case replacingRange
        case line
        case full
        case ignored
    }
    
    public init(
        id: String,
        text: String,
        position: CursorPosition,
        range: CursorRange,
        effectiveRange: EffectiveRange = .replacingRange,
        replacingLines: [String] = [],
        descriptions: [Description] = [],
        middlewareComments: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.text = text
        self.position = position
        self.id = id
        self.range = range
        self.effectiveRange = effectiveRange
        self.replacingLines = replacingLines
        self.descriptions = descriptions
        self.middlewareComments = middlewareComments
        self.metadata = metadata
    }

    public static func == (lhs: CodeSuggestion, rhs: CodeSuggestion) -> Bool {
        return lhs.text == rhs.text
            && lhs.position == rhs.position
            && lhs.id == rhs.id
            && lhs.range == rhs.range
            && lhs.descriptions == rhs.descriptions
            && lhs.middlewareComments == rhs.middlewareComments
    }

    /// The new code to be inserted and the original code on the first line.
    public var text: String
    /// The position of the cursor before generating the completion.
    public var position: CursorPosition
    /// An id.
    public var id: String
    /// The range of the original code that should be replaced.
    public var range: CursorRange
    /// The range of the suggestion that has an effect.
    public var effectiveRange: EffectiveRange
    /// Descriptions about this code suggestion
    @FallbackDecoding<EmptyArray> public var replacingLines: [String]
    /// Descriptions about this code suggestion
    @FallbackDecoding<EmptyArray> public var descriptions: [Description]
    /// A place to store comments inserted by middleware for debugging use.
    @FallbackDecoding<EmptyArray> public var middlewareComments: [String]
    /// A place to store extra data.
    @FallbackDecoding<EmptyDictionary> public var metadata: [String: String]
}

