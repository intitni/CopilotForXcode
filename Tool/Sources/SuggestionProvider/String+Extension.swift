import Foundation

public extension String {
    func removedTrailingWhitespacesAndNewlines() -> String {
        var text = self[...]
        while let last = text.last, last.isNewline || last.isWhitespace {
            text = text.dropLast(1)
        }
        return String(text)
    }
}
