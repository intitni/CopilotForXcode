import Foundation
import GPTEncoder

protocol TokenEncoder {
    func encode(text: String) -> [Int]
}

extension GPTEncoder: TokenEncoder {}

extension TokenEncoder {
    func countToken(message: ChatMessage) -> Int {
        var total = 0
        if let content = message.content {
            total += encode(text: content).count
        }
        if let name = message.name {
            total += encode(text: name).count
        }
        if let functionCall = message.functionCall {
            total += encode(text: functionCall.name).count
            total += encode(text: functionCall.arguments).count
        }
        return total
    }

    func countToken(text: String) -> Int {
        encode(text: text).count
    }
}

