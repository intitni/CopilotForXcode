import Foundation
import SuggestionBasic

/// Splits code into the identifier-ish tokens used to compare two pieces of code.
public enum CodeTokenizer {
    /// Words that appear in almost every file and so carry no signal.
    static let stopWords: Set<String> = [
        "self", "true", "false", "nil", "null", "none", "let", "var", "func", "class", "struct",
        "enum", "protocol", "extension", "import", "return", "if", "else", "guard", "for", "while",
        "in", "case", "switch", "default", "break", "continue", "do", "try", "catch", "throw",
        "throws", "async", "await", "public", "private", "internal", "fileprivate", "static",
        "final", "override", "init", "deinit", "get", "set", "where", "as", "is", "new", "this",
        "const", "int", "string", "bool", "void", "def", "end", "type", "value", "data",
    ]

    /// Tokens shorter than this are noise (`i`, `x`, `id` …).
    static let minimumLength = 3

    public static func tokens<S: Sequence>(in lines: S) -> Set<String> where S.Element == String {
        var result = Set<String>()
        for line in lines {
            var current = ""
            for character in line {
                if character.isLetter || character.isNumber || character == "_" {
                    current.append(character)
                } else {
                    add(current, to: &result)
                    current = ""
                }
            }
            add(current, to: &result)
        }
        return result
    }

    private static func add(_ token: String, to set: inout Set<String>) {
        guard token.count >= minimumLength else { return }
        let lowered = token.lowercased()
        guard !stopWords.contains(lowered) else { return }
        set.insert(lowered)
    }
}

/// A file that has been prepared once so it can be scored cheaply on every keystroke.
public struct IndexedSnippetSource {
    public struct Window {
        public var startLine: Int
        public var endLine: Int
        public var tokens: Set<String>
    }

    public var filePath: String
    public var lines: [String]
    public var windows: [Window]

    public init(filePath: String, lines: [String], windows: [Window]) {
        self.filePath = filePath
        self.lines = lines
        self.windows = windows
    }
}

/// Copilot-style "neighboring tabs" retrieval.
///
/// Every other opened file is cut into fixed windows, each window is scored against the code
/// around the cursor with Jaccard similarity over identifier tokens, and the best windows become
/// reference snippets. It is deliberately index-free: no embeddings, no network, no warm-up.
public enum NeighboringSnippetRetriever {
    public struct Options {
        /// How many lines before the cursor form the query.
        public var referenceWindow: Int
        public var windowSize: Int
        public var windowStride: Int
        public var maxSnippets: Int
        public var maxSnippetsPerFile: Int
        public var minimumScore: Double

        public init(
            referenceWindow: Int = 40,
            windowSize: Int = 30,
            windowStride: Int = 15,
            maxSnippets: Int = 3,
            maxSnippetsPerFile: Int = 1,
            minimumScore: Double = 0.1
        ) {
            self.referenceWindow = referenceWindow
            self.windowSize = windowSize
            self.windowStride = windowStride
            self.maxSnippets = maxSnippets
            self.maxSnippetsPerFile = maxSnippetsPerFile
            self.minimumScore = minimumScore
        }
    }

    public static func index(
        filePath: String,
        lines: [String],
        options: Options = .init()
    ) -> IndexedSnippetSource {
        var windows = [IndexedSnippetSource.Window]()
        guard !lines.isEmpty else {
            return .init(filePath: filePath, lines: lines, windows: windows)
        }
        let size = max(1, options.windowSize)
        let stride = max(1, options.windowStride)
        var start = 0
        while start < lines.count {
            let end = min(lines.count, start + size)
            windows.append(.init(
                startLine: start,
                endLine: end,
                tokens: CodeTokenizer.tokens(in: lines[start..<end])
            ))
            if end == lines.count { break }
            start += stride
        }
        return .init(filePath: filePath, lines: lines, windows: windows)
    }

    public static func queryTokens(
        currentLines: [String],
        cursorPosition: CursorPosition,
        options: Options = .init()
    ) -> Set<String> {
        guard !currentLines.isEmpty else { return [] }
        let cursorLine = min(max(0, cursorPosition.line), currentLines.count - 1)
        let start = max(0, cursorLine - options.referenceWindow)
        let end = min(currentLines.count, cursorLine + 1)
        guard start < end else { return [] }
        return CodeTokenizer.tokens(in: currentLines[start..<end])
    }

    public static func jaccardSimilarity(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
        if lhs.isEmpty || rhs.isEmpty { return 0 }
        let intersection = lhs.intersection(rhs).count
        if intersection == 0 { return 0 }
        let union = lhs.count + rhs.count - intersection
        return Double(intersection) / Double(union)
    }

    public static func retrieve(
        query: Set<String>,
        sources: [IndexedSnippetSource],
        commentPrefix: String = "//",
        options: Options = .init()
    ) -> [RelevantCodeSnippet] {
        guard !query.isEmpty, options.maxSnippets > 0 else { return [] }

        struct Match {
            var filePath: String
            var lines: ArraySlice<String>
            var score: Double
        }

        var matches = [Match]()
        for source in sources {
            var best = [Match]()
            for window in source.windows {
                let score = jaccardSimilarity(query, window.tokens)
                guard score >= options.minimumScore else { continue }
                best.append(.init(
                    filePath: source.filePath,
                    lines: source.lines[window.startLine..<window.endLine],
                    score: score
                ))
            }
            best.sort { $0.score > $1.score }
            matches.append(contentsOf: best.prefix(max(1, options.maxSnippetsPerFile)))
        }

        matches.sort { $0.score > $1.score }
        let chosen = matches.prefix(options.maxSnippets)

        return chosen.enumerated().map { index, match in
            RelevantCodeSnippet(
                content: "\(commentPrefix) Path: \(match.filePath)\n"
                    + match.lines.joined(separator: "\n"),
                priority: chosen.count - index,
                filePath: match.filePath
            )
        }
    }
}
