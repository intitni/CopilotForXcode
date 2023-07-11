import Foundation
import Tiktoken

public final class TiktokenCl100kBaseTokenEncoder: TokenEncoder {
    static var encoding: Encoding?
    static var isLoadingEncoding = false

    public init() {}

    public func encode(text: String) -> [Int] {
        guard let encoding = Self.createEncodingIfNeeded() else { return [] }
        return encoding.encode(value: text)
    }

    static func createEncodingIfNeeded() -> Encoding? {
        if let encoding = Self.encoding { return encoding }
        let encoding = Tiktoken.shared.getEncoding(
            for: Vocab.cl100kBase,
            name: "gpt-4",
            fileURL: Bundle.module.url(forResource: "cl100k_base", withExtension: "tiktoken")!
        )!
        Self.encoding = encoding
        return encoding
    }
}

