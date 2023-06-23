import AppKit
import Foundation

public struct TextLoader: DocumentLoader {
    let url: URL
    let encoding: String.Encoding
    let options: [NSAttributedString.DocumentReadingOptionKey: Any]

    public init(
        url: URL,
        encoding: String.Encoding = .utf8,
        options: [NSAttributedString.DocumentReadingOptionKey: Any] = [:]
    ) {
        self.url = url
        self.encoding = encoding
        self.options = options
    }

    public func load() async throws -> [Document] {
        let data = try Data(contentsOf: url)
        let attributedString = try NSAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        )
        let modificationDate = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate
        return [Document(pageContent: attributedString.string, metadata: [
            "filename": url.lastPathComponent,
            "extension": url.pathExtension,
            "contentModificationDate": modificationDate ?? Date(),
        ])]
    }
}

