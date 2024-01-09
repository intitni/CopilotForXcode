import LanguageServerProtocol

/// Line starts at 0.
public typealias CursorPosition = LanguageServerProtocol.Position

public extension CursorPosition {
    static let zero = CursorPosition(line: 0, character: 0)
    static var outOfScope: CursorPosition { .init(line: -1, character: -1) }
    
    var readableText: String {
        return "[\(line + 1), \(character)]"
    }
}

public struct CursorRange: Codable, Hashable, Sendable, Equatable, CustomStringConvertible {
    public static let zero = CursorRange(start: .zero, end: .zero)

    public var start: CursorPosition
    public var end: CursorPosition

    public init(start: Position, end: Position) {
        self.start = start
        self.end = end
    }

    public init(startPair: (Int, Int), endPair: (Int, Int)) {
        start = CursorPosition(startPair)
        end = CursorPosition(endPair)
    }

    public func contains(_ position: CursorPosition) -> Bool {
        return position >= start && position <= end
    }

    public func contains(_ range: CursorRange) -> Bool {
        return range.start >= start && range.end <= end
    }
    
    public func strictlyContains(_ range: CursorRange) -> Bool {
        return range.start > start && range.end < end
    }

    public func intersects(_ other: LSPRange) -> Bool {
        return contains(other.start) || contains(other.end)
    }

    public var isEmpty: Bool {
        return start == end
    }
    
    public var isOneLine: Bool {
        return start.line == end.line
    }
    
    /// The number of lines in the range.
    public var lineCount: Int {
        return end.line - start.line + 1
    }
    
    public static func == (lhs: CursorRange, rhs: CursorRange) -> Bool {
        return lhs.start == rhs.start && lhs.end == rhs.end
    }
    
    public var description: String {
        return "\(start.readableText) - \(end.readableText)"
    }
}

public extension CursorRange {
    static var outOfScope: CursorRange { .init(start: .outOfScope, end: .outOfScope) }
    static func cursor(_ position: CursorPosition) -> CursorRange {
        return .init(start: position, end: position)
    }
}

