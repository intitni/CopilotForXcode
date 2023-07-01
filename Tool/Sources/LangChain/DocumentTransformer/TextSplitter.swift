import Foundation
import JSONRPC

/// Split text into multiple components.
public protocol TextSplitter: DocumentTransformer {
    /// The maximum size of chunks.
    var chunkSize: Int { get }
    /// The maximum overlap between chunks.
    var chunkOverlap: Int { get }
    /// A function to compute the length of text.
    var lengthFunction: (String) -> Int { get }

    /// Split text into multiple components.
    func split(text: String) async throws -> [String]
}

public extension TextSplitter {
    /// Create documents from a list of texts.
    func createDocuments(
        texts: [String],
        metadata: [Document.Metadata] = []
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
        var metadata = [Document.Metadata]()
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

public extension TextSplitter {
    /// Merge small splits to just fit in the chunk size.
    func mergeSplits(_ splits: [String]) -> [String] {
        let chunkOverlap = chunkOverlap < chunkSize ? chunkOverlap : 0

        var chunks = [String]()
        var currentChunk = [String]()
        var overlappingChunks = [String]()
        var currentChunkSize = 0
        
        func join(_ a: [String], _ b: [String]) -> String {
            return (a + b).joined().trimmingCharacters(in: .whitespaces)
        }

        for text in splits {
            let textLength = lengthFunction(text)
            if currentChunkSize + textLength > chunkSize {
                let currentChunkText = join(overlappingChunks, currentChunk)
                chunks.append(currentChunkText)

                overlappingChunks = []
                var overlappingSize = 0
                // use small chunks as overlap if possible
                for chunk in currentChunk.reversed() {
                    let length = lengthFunction(chunk)
                    if overlappingSize + length > chunkOverlap { break }
                    if overlappingSize + length + textLength > chunkSize { break }
                    overlappingSize += length
                    overlappingChunks.insert(chunk, at: 0)
                }
//                // fallback to use suffix if no small chunk found
//                if overlappingChunks.isEmpty {
//                    let suffix = String(
//                        currentChunkText.suffix(min(chunkOverlap, chunkSize - textLength))
//                    )
//                    overlappingChunks.append(suffix)
//                    overlappingSize = lengthFunction(suffix)
//                }

                currentChunkSize = overlappingSize + textLength
                currentChunk = [text]
            } else {
                currentChunkSize += textLength
                currentChunk.append(text)
            }
        }

        if !currentChunk.isEmpty {
            chunks.append(join(overlappingChunks, currentChunk))
        }

        return chunks
    }

    /// Split the text by separator.
    func split(text: String, separator: String) -> [String] {
        guard !separator.isEmpty else {
            return [text]
        }

        let pattern = "(\(separator))"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            var all = [String]()
            var start = text.startIndex
            for match in matches {
                guard let range = Range(match.range, in: text) else { break }
                guard range.lowerBound > start else { break }
                let result = text[start..<range.lowerBound]
                start = range.lowerBound
                if !result.isEmpty {
                    all.append(String(result))
                }
            }
            if start < text.endIndex {
                all.append(String(text[start...]))
            }
            return all
        } else {
            return [text]
        }
    }
}

