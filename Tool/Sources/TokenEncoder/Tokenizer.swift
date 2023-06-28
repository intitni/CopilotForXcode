import Foundation

public protocol TokenEncoder {
    func encode(text: String) -> [Int]
}

public extension TokenEncoder {
    func countToken(text: String) -> Int {
        encode(text: text).count
    }
}
