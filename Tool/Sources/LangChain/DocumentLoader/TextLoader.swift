import AppKit
import Foundation

/// Load a text document from local file.
public struct TextLoader: DocumentLoader {
    enum MetadataKeys {
        static let filename = "filename"
        static let `extension` = "extension"
        static let contentModificationDate = "contentModificationDate"
    }
    
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
            MetadataKeys.filename: .string(url.lastPathComponent),
            MetadataKeys.extension: .string(url.pathExtension),
            MetadataKeys.contentModificationDate: .number(
                (modificationDate ?? Date()).timeIntervalSince1970
            ),
        ])]
    }
}

