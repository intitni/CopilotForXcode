import LanguageServerProtocol

public typealias CursorPosition = LanguageServerProtocol.Position

public extension CursorPosition {
    static let zero = CursorPosition(line: 0, character: 0)
    static var outOfScope: CursorPosition { .init(line: -1, character: -1) }
}

public struct CursorRange: Codable, Hashable, Sendable {
    static let zero = CursorRange(start: .zero, end: .zero)

    public var start: CursorPosition
    public var end: CursorPosition

    public init(start: Position, end: Position) {
        self.start = start
        self.end = end
    }

    public init(startPair: (Int, Int), endPair: (Int, Int)) {
        self.start = Position(startPair)
        self.end = Position(endPair)
    }

    public func contains(_ position: Position) -> Bool {
        return position > start && position < end
    }

    public func intersects(_ other: LSPRange) -> Bool {
        return contains(other.start) || contains(other.end)
    }

    public var isEmpty: Bool {
        return start == end
    }
}

public extension CursorRange {
    static var outOfScope: CursorRange { .init(start: .outOfScope, end: .outOfScope) }
    static func cursor(_ position: CursorPosition) -> CursorRange {
        return .init(start: position, end: position)
    }
}
