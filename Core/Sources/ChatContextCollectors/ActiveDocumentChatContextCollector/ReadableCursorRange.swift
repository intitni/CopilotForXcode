import SuggestionModel

extension CursorPosition: CustomStringConvertible {
    var description: String {
        "[\(line), \(character)]"
    }
}

extension CursorRange: CustomStringConvertible {
    var description: String {
        "\(start.description) - \(end.description)"
    }
}
