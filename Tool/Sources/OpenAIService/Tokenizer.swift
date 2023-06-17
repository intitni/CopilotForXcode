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
            if let arguments = functionCall.arguments {
                total += encode(text: arguments).count
            }
        }
        return total
    }

    func countToken(functionJSONSchema: String) -> Int {
        encode(text: functionJSONSchema).count
    }
}

