import SuggestionBasic
import XCTest
@testable import Service
@testable import XPCShared

class ExtractSelectedCodeTests: XCTestCase {
    func test_empty_selection() {
        let selection = EditorContent.Selection(
            start: CursorPosition(line: 0, character: 0),
            end: CursorPosition(line: 0, character: 0)
        )
        let lines = ["let foo = 1\n", "let bar = 2\n"]
        let result = selectedCode(in: selection, for: lines)
        XCTAssertEqual(result, "")
    }

    func test_single_line_selection() {
        let selection = EditorContent.Selection(
            start: CursorPosition(line: 0, character: 4),
            end: CursorPosition(line: 0, character: 10)
        )
        let lines = ["let foo = 1\n", "let bar = 2\n"]
        let result = selectedCode(in: selection, for: lines)
        XCTAssertEqual(result, "foo = ")
    }

    func test_single_line_selection_at_line_end() {
        let selection = EditorContent.Selection(
            start: CursorPosition(line: 0, character: 8),
            end: CursorPosition(line: 0, character: 11)
        )
        let lines = ["let foo = 1\n", "let bar = 2\n"]
        let result = selectedCode(in: selection, for: lines)
        XCTAssertEqual(result, "= 1")
    }

    func test_multi_line_selection() {
        let selection = EditorContent.Selection(
            start: CursorPosition(line: 0, character: 4),
            end: CursorPosition(line: 1, character: 11)
        )
        let lines = ["let foo = 1\n", "let bar = 2\n", "let baz = 3\n"]
        let result = selectedCode(in: selection, for: lines)
        XCTAssertEqual(result, "foo = 1\nlet bar = 2")
    }

    func test_invalid_selection() {
        let selection = EditorContent.Selection(
            start: CursorPosition(line: 1, character: 4),
            end: CursorPosition(line: 0, character: 10)
        )
        let lines = ["let foo = 1", "let bar = 2"]
        let result = selectedCode(in: selection, for: lines)
        XCTAssertEqual(result, "")
    }
}
