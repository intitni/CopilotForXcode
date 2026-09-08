import Foundation
import XCTest

@testable import SuggestionProvider

final class RecentEditDiffTests: XCTestCase {
    func test_no_change_produces_no_hunk() {
        XCTAssertNil(RecentEditDiff.hunk(
            filePath: "A.swift",
            before: ["a", "b"],
            after: ["a", "b"]
        ))
    }

    func test_insertion() {
        let hunk = RecentEditDiff.hunk(
            filePath: "A.swift",
            before: ["a", "c"],
            after: ["a", "b", "c"]
        )
        XCTAssertEqual(hunk?.startLine, 1)
        XCTAssertEqual(hunk?.removed, [])
        XCTAssertEqual(hunk?.inserted, ["b"])
    }

    func test_deletion() {
        let hunk = RecentEditDiff.hunk(
            filePath: "A.swift",
            before: ["a", "b", "c"],
            after: ["a", "c"]
        )
        XCTAssertEqual(hunk?.startLine, 1)
        XCTAssertEqual(hunk?.removed, ["b"])
        XCTAssertEqual(hunk?.inserted, [])
    }

    func test_replacement_keeps_only_the_changed_middle() {
        let hunk = RecentEditDiff.hunk(
            filePath: "A.swift",
            before: ["head", "old1", "old2", "tail"],
            after: ["head", "new1", "tail"]
        )
        XCTAssertEqual(hunk?.startLine, 1)
        XCTAssertEqual(hunk?.removed, ["old1", "old2"])
        XCTAssertEqual(hunk?.inserted, ["new1"])
    }

    func test_line_endings_are_normalized_before_comparing() {
        XCTAssertNil(RecentEditDiff.hunk(
            filePath: "A.swift",
            before: ["a\n", "b\n"],
            after: ["a", "b"]
        ))

        let hunk = RecentEditDiff.hunk(
            filePath: "A.swift",
            before: ["let a = 1\n"],
            after: ["let a = 12\n"]
        )
        XCTAssertEqual(hunk?.removed, ["let a = 1"])
        XCTAssertEqual(hunk?.inserted, ["let a = 12"])
    }

    func test_typing_at_the_end_of_a_file() {
        let hunk = RecentEditDiff.hunk(
            filePath: "A.swift",
            before: ["a", ""],
            after: ["a", "b"]
        )
        XCTAssertEqual(hunk?.startLine, 1)
        XCTAssertEqual(hunk?.removed, [""])
        XCTAssertEqual(hunk?.inserted, ["b"])
    }
}

final class RecentEditSnippetBuilderTests: XCTestCase {
    func makeHunk(_ path: String, inserted: [String]) -> RecentEditHunk {
        .init(filePath: path, startLine: 0, removed: [], inserted: inserted)
    }

    func test_no_hunks_produces_no_snippet() {
        XCTAssertNil(RecentEditSnippetBuilder.snippet(from: [], priority: 1))
    }

    func test_every_line_is_commented_out() {
        let snippet = RecentEditSnippetBuilder.snippet(
            from: [.init(
                filePath: "A.swift",
                startLine: 3,
                removed: ["var a: Int"],
                inserted: ["var a: Int = 0"]
            )],
            priority: 4
        )
        let lines = snippet?.content.components(separatedBy: "\n") ?? []
        XCTAssertFalse(lines.isEmpty)
        for line in lines {
            XCTAssertTrue(line.hasPrefix("//"), "unsafe line in a code prompt: \(line)")
        }
        XCTAssertTrue(lines.contains("// --- A.swift"))
        XCTAssertTrue(lines.contains("// - var a: Int"))
        XCTAssertTrue(lines.contains("// + var a: Int = 0"))
        XCTAssertEqual(snippet?.priority, 4)
    }

    func test_uses_the_language_comment_prefix() {
        let snippet = RecentEditSnippetBuilder.snippet(
            from: [makeHunk("a.py", inserted: ["x = 1"])],
            commentPrefix: CodeCommentStyle.prefix(forFileExtension: "py"),
            priority: 1
        )
        XCTAssertTrue(snippet?.content.contains("# + x = 1") ?? false)
    }

    func test_keeps_only_the_most_recent_hunks() {
        let snippet = RecentEditSnippetBuilder.snippet(
            from: [
                makeHunk("Oldest.swift", inserted: ["a"]),
                makeHunk("Middle.swift", inserted: ["b"]),
                makeHunk("Newest.swift", inserted: ["c"]),
            ],
            priority: 1,
            maxHunks: 2
        )
        let content = snippet?.content ?? ""
        XCTAssertFalse(content.contains("Oldest.swift"))
        XCTAssertTrue(content.contains("Middle.swift"))
        XCTAssertTrue(content.contains("Newest.swift"))
    }

    func test_truncates_long_hunks() {
        let snippet = RecentEditSnippetBuilder.snippet(
            from: [makeHunk("A.swift", inserted: (0..<10).map { "line\($0)" })],
            priority: 1,
            maxLinesPerHunk: 2
        )
        let content = snippet?.content ?? ""
        XCTAssertTrue(content.contains("// + line0"))
        XCTAssertTrue(content.contains("// + line1"))
        XCTAssertFalse(content.contains("// + line2"))
        XCTAssertTrue(content.contains("8 more lines"))
    }

    func test_comment_style_defaults_to_double_slash() {
        XCTAssertEqual(CodeCommentStyle.prefix(forFileExtension: "swift"), "//")
        XCTAssertEqual(CodeCommentStyle.prefix(forFileExtension: "SQL"), "--")
        XCTAssertEqual(CodeCommentStyle.prefix(forFileExtension: "unknown"), "//")
    }
}
