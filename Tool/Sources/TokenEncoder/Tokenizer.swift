import Foundation

public protocol TokenEncoder: TokenCounter {
    func encode(text: String) -> [Int]
}

extension TokenEncoder {
    func countToken(text: String) -> Int {
        encode(text: text).count
    }
}

public protocol TokenCounter {
    func countToken(text: String) -> Int
}
