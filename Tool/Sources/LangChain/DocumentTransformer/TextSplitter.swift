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
    func split(text: String) async throws -> [TextChunk]
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
            let chunks = try await split(text: text)
            for chunk in chunks {
                let document = Document(pageContent: chunk.text, metadata: metadata)
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

public struct TextChunk: Equatable {
    public var text: String
    public var startUTF16Offset: Int
    public var endUTF16Offset: Int

    /// Merge the current chunk with another chunk if the 2 chunks are overlapping or adjacent.
    public func merged(with chunk: TextChunk, force: Bool = false) -> TextChunk? {
        let frontChunk = startUTF16Offset < chunk.startUTF16Offset ? self : chunk
        let backChunk = startUTF16Offset < chunk.startUTF16Offset ? chunk : self
        let overlap = frontChunk.endUTF16Offset - backChunk.startUTF16Offset
        guard overlap >= 0 || force else { return nil }

        let text = frontChunk.text + backChunk.text.dropFirst(max(0, overlap))
        let start = frontChunk.startUTF16Offset
        let end = backChunk.endUTF16Offset
        return TextChunk(text: text, startUTF16Offset: start, endUTF16Offset: end)
    }
}

public extension TextSplitter {
    /// Merge small splits to just fit in the chunk size.
    func mergeSplits(_ splits: [TextChunk]) -> [TextChunk] {
        let chunkOverlap = chunkOverlap < chunkSize ? chunkOverlap : 0

        var chunks = [TextChunk]()
        var currentChunk = [TextChunk]()
        var overlappingChunks = [TextChunk]()
        var currentChunkSize = 0

        func join(_ a: [TextChunk], _ b: [TextChunk]) -> TextChunk? {
            let text = (a + b).map(\.text).joined()
            var l = Int.max
            var u = 0
            
            for chunk in a + b {
                l = min(l, chunk.startUTF16Offset)
                u = max(u, chunk.endUTF16Offset)
            }
            
            guard l < u else { return nil }
            
            return .init(text: text, startUTF16Offset: l, endUTF16Offset: u)
        }

        for chunk in splits {
            let textLength = lengthFunction(chunk.text)
            if currentChunkSize + textLength > chunkSize {
                guard let currentChunkText = join(overlappingChunks, currentChunk) else { continue }
                chunks.append(currentChunkText)

                overlappingChunks = []
                var overlappingSize = 0
                // use small chunks as overlap if possible
                for chunk in currentChunk.reversed() {
                    let length = lengthFunction(chunk.text)
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
                currentChunk = [chunk]
            } else {
                currentChunkSize += textLength
                currentChunk.append(chunk)
            }
        }

        if !currentChunk.isEmpty, let joinedChunks = join(overlappingChunks, currentChunk) {
            chunks.append(joinedChunks)
        } else {
            chunks.append(contentsOf: overlappingChunks)
            chunks.append(contentsOf: currentChunk)
        }

        return chunks
    }

    /// Split the text by separator.
    func split(text: String, separator: String, startIndex: Int = 0) -> [TextChunk] {
        let pattern = "(\(separator))"
        if !separator.isEmpty, let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            var all = [TextChunk]()
            var start = text.startIndex
            for match in matches {
                guard let range = Range(match.range, in: text) else { break }
                guard range.lowerBound > start else { break }
                let result = text[start..<range.lowerBound]
                if !result.isEmpty {
                    all.append(.init(
                        text: String(result),
                        startUTF16Offset: start.utf16Offset(in: text) + startIndex,
                        endUTF16Offset: range.lowerBound.utf16Offset(in: text) + startIndex
                    ))
                }
                start = range.lowerBound
            }
            if start < text.endIndex {
                all.append(.init(
                    text: String(text[start...]),
                    startUTF16Offset: start.utf16Offset(in: text) + startIndex,
                    endUTF16Offset: text.endIndex.utf16Offset(in: text) + startIndex
                ))
            }
            return all
        } else {
            return [.init(
                text: text,
                startUTF16Offset: text.startIndex.utf16Offset(in: text) + startIndex,
                endUTF16Offset: text.endIndex.utf16Offset(in: text) + startIndex
            )]
        }
    }
}

