import Foundation

public struct CharacterTokenCounter: TokenCounter {
    public func countToken(text: String) -> Int {
        text.count
    }
}
