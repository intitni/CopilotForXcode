import LanguageServerProtocol

public typealias CursorPosition = LanguageServerProtocol.Position
public typealias CursorRange = LanguageServerProtocol.LSPRange

public extension CursorPosition {
    static var outOfScope: CursorPosition { .init(line: -1, character: -1) }
}
