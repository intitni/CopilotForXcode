import Foundation

public extension String {
    func removedTrailingWhitespacesAndNewlines() -> String {
        var text = self[...]
        while let last = text.last, last.isNewline || last.isWhitespace {
            text = text.dropLast(1)
        }
        return String(text)
    }
    
    func removedTrailingCharacters(in set: CharacterSet) -> String {
        var text = self[...]
        while let last = text.last, set.containsUnicodeScalars(of: last) {
            text = text.dropLast(1)
        }
        return String(text)
    }
    
    func removeLeadingCharacters(in set: CharacterSet) -> String {
        var text = self[...]
        while let first = text.first, set.containsUnicodeScalars(of: first) {
            text = text.dropFirst()
        }
        return String(text)
    }
}

extension CharacterSet {
    func containsUnicodeScalars(of character: Character) -> Bool {
        return character.unicodeScalars.allSatisfy(contains(_:))
    }
}
