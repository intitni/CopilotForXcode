import Foundation
import JSONRPC

public protocol DocumentTransformer {
    func transformDocuments(_ documents: [Document]) async throws -> [Document]
}

public protocol TextSplitter: DocumentTransformer {
    /// Split text into multiple components.
    func split(text: String) async throws -> [String]
}

public extension TextSplitter {
    /// Create documents from a list of texts.
    func createDocuments(
        texts: [String],
        metadata: [JSONValue] = []
    ) async throws -> [Document] {
        var documents = [Document]()
        let paddingLength = texts.count - metadata.count
        let metadata = metadata + .init(repeating: [:], count: paddingLength)
        for (text, metadata) in zip(texts, metadata) {
            let trunks = try await split(text: text)
            for trunk in trunks {
                let document = Document(pageContent: trunk, metadata: metadata)
                documents.append(document)
            }
        }
        return documents
    }

    /// Split documents.
    func splitDocuments(_ documents: [Document]) async throws -> [Document] {
        var texts = [String]()
        var metadata = [JSONValue]()
        for document in documents {
            texts.append(document.pageContent)
            metadata.append(document.metadata)
        }
        return try await createDocuments(texts: texts, metadata: metadata)
    }

    /// Transform sequence of documents by splitting them.
    func transformDocuments(_ documents: [Document]) async throws -> [Document] {
        return try await splitDocuments(documents)
    }
}

extension TextSplitter {}

