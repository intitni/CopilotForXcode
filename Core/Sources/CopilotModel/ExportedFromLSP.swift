import LanguageServerProtocol

public typealias CursorPosition = LanguageServerProtocol.Position
public typealias CursorRange = LanguageServerProtocol.LSPRange

public extension CursorPosition {
    static var outOfScope: CursorPosition { .init(line: -1, character: -1) }
}

public extension CursorRange {
    static var outOfScope: CursorRange { .init(start: .outOfScope, end: .outOfScope) }
    static func cursor(_ position: CursorPosition) -> CursorRange {
        return .init(start: position, end: position)
    }
}
