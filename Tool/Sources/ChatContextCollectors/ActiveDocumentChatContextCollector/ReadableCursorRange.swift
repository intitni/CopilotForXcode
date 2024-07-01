import SuggestionBasic

extension CursorPosition {
    var text: String {
        "[\(line), \(character)]"
    }
}

extension CursorRange {
    var text: String {
        "\(start.description) - \(end.description)"
    }
}
