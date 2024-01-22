import Foundation

/// Implementation of splitting text that looks at characters.
/// Recursively tries to split by different characters to find one that works.
public class RecursiveCharacterTextSplitter: TextSplitter {
    public var chunkSize: Int
    public var chunkOverlap: Int
    public var lengthFunction: (String) -> Int

    /// A list of separators to try. They will be used in order. Supports regular expressions.
    public var separators: [String]

    /// Create a new splitter
    /// - Parameters:
    ///    - separators: A list of separators to try. They will be used in order. Supports regular
    /// expressions.
    ///    - chunkSize: The maximum size of chunks. Don't use chunk size larger than 8191, because
    /// length safe embedding is not implemented.
    ///    - chunkOverlap: The maximum overlap between chunks.
    ///    - lengthFunction: A function to compute the length of text.
    public init(
        separators: [String],
        chunkSize: Int = 4000,
        chunkOverlap: Int = 200,
        lengthFunction: @escaping (String) -> Int = { $0.count }
    ) {
        assert(chunkOverlap <= chunkSize)
        self.chunkSize = chunkSize
        self.chunkOverlap = chunkOverlap
        self.lengthFunction = lengthFunction
        self.separators = separators
    }

    // Create a new splitter
    /// - Parameters:
    ///    - separatorSet: A set of separators to try.
    ///    - chunkSize: The maximum size of chunks. Don't use chunk size larger than 8191, because
    /// length safe embedding is not implemented.
    ///    - chunkOverlap: The maximum overlap between chunks.
    ///    - lengthFunction: A function to compute the length of text.
    public init(
        separatorSet: TextSplitterSeparatorSet = .default,
        chunkSize: Int = 4000,
        chunkOverlap: Int = 200,
        lengthFunction: @escaping (String) -> Int = { $0.count }
    ) {
        assert(chunkOverlap <= chunkSize)
        self.chunkSize = chunkSize
        self.chunkOverlap = chunkOverlap
        self.lengthFunction = lengthFunction
        separators = separatorSet.separators
    }

    public func split(text: String) async throws -> [TextChunk] {
        return split(text: text, separators: separators, startIndex: 0)
    }

    private func split(text: String, separators: [String], startIndex: Int) -> [TextChunk] {
        var finalChunks = [TextChunk]()

        // Get appropriate separator to use
        let firstSeparatorIndex = separators.firstIndex {
            let pattern = "(\($0))"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
            return regex.firstMatch(
                in: text,
                options: [],
                range: NSRange(text.startIndex..., in: text)
            ) != nil
        }
        var separator: String
        var nextSeparators: [String]

        if let index = firstSeparatorIndex {
            separator = separators[index]
            if index < separators.endIndex - 1 {
                nextSeparators = Array(separators[(index + 1)...])
            } else {
                nextSeparators = []
            }
        } else {
            separator = ""
            nextSeparators = []
        }

        let splits = split(text: text, separator: separator, startIndex: startIndex)

        // Now go merging things, recursively splitting longer texts.
        var goodSplits = [TextChunk]()
        for s in splits {
            if lengthFunction(s.text) < chunkSize {
                goodSplits.append(s)
            } else {
                if !goodSplits.isEmpty {
                    let mergedText = mergeSplits(goodSplits)
                    finalChunks.append(contentsOf: mergedText)
                    goodSplits.removeAll()
                }
                if nextSeparators.isEmpty {
                    finalChunks.append(s)
                } else {
                    let other_info = split(
                        text: s.text,
                        separators: nextSeparators,
                        startIndex: s.startUTF16Offset
                    )
                    finalChunks.append(contentsOf: other_info)
                }
            }
        }
        if !goodSplits.isEmpty {
            let merged_text = mergeSplits(goodSplits)
            finalChunks.append(contentsOf: merged_text)
        }
        return finalChunks
    }
}

