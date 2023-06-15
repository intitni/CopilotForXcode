import Foundation
import GPTEncoder

protocol TokenEncoder {
    func encode(text: String) -> [Int]
}

extension GPTEncoder: TokenEncoder {}

