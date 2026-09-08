import Foundation

/// Line comment token per language, so injected context stays valid code wherever it lands.
public enum CodeCommentStyle {
    public static func prefix(forFileExtension fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "py", "rb", "sh", "bash", "zsh", "yml", "yaml", "toml", "pl", "r", "cmake":
            return "#"
        case "sql", "lua", "hs", "elm", "applescript":
            return "--"
        default:
            return "//"
        }
    }
}

/// One observed change to a file: the lines that were there and the lines that replaced them.
public struct RecentEditHunk: Equatable {
    public var filePath: String
    public var startLine: Int
    public var removed: [String]
    public var inserted: [String]

    public init(filePath: String, startLine: Int, removed: [String], inserted: [String]) {
        self.filePath = filePath
        self.startLine = startLine
        self.removed = removed
        self.inserted = inserted
    }
}

public enum RecentEditDiff {
    /// Diffs two versions of a file by trimming the common head and tail.
    ///
    /// Suggestion rounds fire while the user types, so the delta between two rounds is almost
    /// always a single contiguous edit. That makes the cheap trim as accurate as a real diff here,
    /// and it stays O(n) on every keystroke.
    public static func hunk(
        filePath: String,
        before: [String],
        after: [String]
    ) -> RecentEditHunk? {
        let normalizedBefore = before.map(trimNewline)
        let normalizedAfter = after.map(trimNewline)

        var head = 0
        while head < normalizedBefore.count,
              head < normalizedAfter.count,
              normalizedBefore[head] == normalizedAfter[head]
        {
            head += 1
        }

        var tail = 0
        while tail < normalizedBefore.count - head,
              tail < normalizedAfter.count - head,
              normalizedBefore[normalizedBefore.count - 1 - tail]
              == normalizedAfter[normalizedAfter.count - 1 - tail]
        {
            tail += 1
        }

        let removed = Array(normalizedBefore[head..<(normalizedBefore.count - tail)])
        let inserted = Array(normalizedAfter[head..<(normalizedAfter.count - tail)])
        guard !(removed.isEmpty && inserted.isEmpty) else { return nil }

        return .init(
            filePath: filePath,
            startLine: head,
            removed: removed,
            inserted: inserted
        )
    }

    static func trimNewline(_ line: String) -> String {
        var line = line
        while let last = line.last, last.isNewline { line.removeLast() }
        return line
    }
}

/// Renders recent edits as a comment block.
///
/// This is the one signal Cursor Tab has that plain retrieval does not: knowing what the user just
/// changed usually says more about the next edit than anything else in the file.
public enum RecentEditSnippetBuilder {
    public static let header =
        "The user's most recent edits, oldest first. They show what the user is doing right now."

    public static func snippet(
        from hunks: [RecentEditHunk],
        commentPrefix: String = "//",
        priority: Int,
        maxLinesPerHunk: Int = 8,
        maxHunks: Int = 3
    ) -> RelevantCodeSnippet? {
        let hunks = Array(hunks.suffix(maxHunks))
        guard !hunks.isEmpty else { return nil }

        var lines = ["\(commentPrefix) \(header)"]
        for hunk in hunks {
            lines.append("\(commentPrefix) --- \(hunk.filePath)")
            lines.append(contentsOf: render(
                hunk.removed,
                marker: "-",
                commentPrefix: commentPrefix,
                maxLines: maxLinesPerHunk
            ))
            lines.append(contentsOf: render(
                hunk.inserted,
                marker: "+",
                commentPrefix: commentPrefix,
                maxLines: maxLinesPerHunk
            ))
        }

        return .init(
            content: lines.joined(separator: "\n"),
            priority: priority,
            filePath: hunks.last?.filePath ?? ""
        )
    }

    private static func render(
        _ lines: [String],
        marker: String,
        commentPrefix: String,
        maxLines: Int
    ) -> [String] {
        guard !lines.isEmpty else { return [] }
        var rendered = lines.prefix(maxLines).map { "\(commentPrefix) \(marker) \($0)" }
        if lines.count > maxLines {
            rendered.append("\(commentPrefix) \(marker) … \(lines.count - maxLines) more lines")
        }
        return rendered
    }
}
