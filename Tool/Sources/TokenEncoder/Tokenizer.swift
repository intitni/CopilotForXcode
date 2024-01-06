import Foundation

public protocol TokenEncoder: TokenCounter {
    func encode(text: String) async -> [Int]
}

public extension TokenEncoder {
    func countToken(text: String) async -> Int {
        await encode(text: text).count
    }
}

public protocol TokenCounter {
    func countToken(text: String) async -> Int
}
