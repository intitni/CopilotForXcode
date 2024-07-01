import Foundation
import XCTest
@testable import SuggestionBasic

final class TextExtrationFromCodeTests: XCTestCase {
    func test_empty_selection() {
        let selection = CursorRange(
            start: CursorPosition(line: 0, character: 0),
            end: CursorPosition(line: 0, character: 0)
        )
        let lines = ["let foo = 1\n", "let bar = 2\n"]
        let result = EditorInformation.code(
            in: lines,
            inside: selection,
            ignoreColumns: false
        )
        XCTAssertEqual(result.code, "")
        XCTAssertEqual(result.lines, ["let foo = 1\n"])
    }

    func test_single_line_selection() {
        let selection = CursorRange(
            start: CursorPosition(line: 0, character: 4),
            end: CursorPosition(line: 0, character: 10)
        )
        let lines = ["let foo = 1\n", "let bar = 2\n"]
        let result = EditorInformation.code(
            in: lines,
            inside: selection,
            ignoreColumns: false
        )
        XCTAssertEqual(result.code, "foo = ")
        XCTAssertEqual(result.lines, ["let foo = 1\n"])
    }

    func test_single_line_selection_with_emoji() {
        let selection = CursorRange(
            start: CursorPosition(line: 0, character: 4),
            end: CursorPosition(line: 0, character: 10)
        )
        let lines = ["let 🎆🎆o = 1\n", "let bar = 2\n"]
        let result = EditorInformation.code(
            in: lines,
            inside: selection,
            ignoreColumns: false
        )
        XCTAssertEqual(result.code, "🎆🎆o ")
        XCTAssertEqual(result.lines, ["let 🎆🎆o = 1\n"])
    }

    func test_single_line_selection_cutting_emoji() {
        // undefined behavior

        let selection = CursorRange(
            start: CursorPosition(line: 0, character: 5),
            end: CursorPosition(line: 0, character: 10)
        )
        let lines = ["let 🎆🎆o = 1\n", "let bar = 2\n"]
        let result = EditorInformation.code(
            in: lines,
            inside: selection,
            ignoreColumns: false
        )
        XCTAssertEqual(result.lines, ["let 🎆🎆o = 1\n"])
    }

    func test_single_line_selection_at_line_end() {
        let selection = CursorRange(
            start: CursorPosition(line: 0, character: 8),
            end: CursorPosition(line: 0, character: 11)
        )
        let lines = ["let foo = 1\n", "let bar = 2\n"]
        let result = EditorInformation.code(
            in: lines,
            inside: selection,
            ignoreColumns: false
        )
        XCTAssertEqual(result.code, "= 1")
        XCTAssertEqual(result.lines, ["let foo = 1\n"])
    }

    func test_multi_line_selection() {
        let selection = CursorRange(
            start: CursorPosition(line: 0, character: 4),
            end: CursorPosition(line: 1, character: 11)
        )
        let lines = ["let foo = 1\n", "let bar = 2\n", "let baz = 3\n"]
        let result = EditorInformation.code(
            in: lines,
            inside: selection,
            ignoreColumns: false
        )
        XCTAssertEqual(result.code, "foo = 1\nlet bar = 2")
        XCTAssertEqual(result.lines, ["let foo = 1\n", "let bar = 2\n"])
    }

    func test_multi_line_selection_with_emoji() {
        let selection = CursorRange(
            start: CursorPosition(line: 0, character: 4),
            end: CursorPosition(line: 1, character: 11)
        )
        let lines = ["🎆🎆 foo = 1\n", "let bar = 2\n", "let baz = 3\n"]
        let result = EditorInformation.code(
            in: lines,
            inside: selection,
            ignoreColumns: false
        )
        XCTAssertEqual(result.code, " foo = 1\nlet bar = 2")
        XCTAssertEqual(result.lines, ["🎆🎆 foo = 1\n", "let bar = 2\n"])
    }

    func test_invalid_selection() {
        let selection = CursorRange(
            start: CursorPosition(line: 1, character: 4),
            end: CursorPosition(line: 0, character: 10)
        )
        let lines = ["let foo = 1", "let bar = 2"]
        let result = EditorInformation.code(
            in: lines,
            inside: selection,
            ignoreColumns: false
        )
        XCTAssertEqual(result.code, "")
        XCTAssertEqual(result.lines, [])
    }
    
    func test_single_line_selection_ignoring_column() {
        let selection = CursorRange(
            start: CursorPosition(line: 0, character: 4),
            end: CursorPosition(line: 0, character: 10)
        )
        let lines = ["let foo = 1\n", "let bar = 2\n"]
        let result = EditorInformation.code(
            in: lines,
            inside: selection,
            ignoreColumns: true
        )
        XCTAssertEqual(result.code, "let foo = 1\n")
        XCTAssertEqual(result.lines, ["let foo = 1\n"])
    }
    
    func test_multi_line_selection_ignoring_column() {
        let selection = CursorRange(
            start: CursorPosition(line: 0, character: 4),
            end: CursorPosition(line: 1, character: 11)
        )
        let lines = ["let foo = 1\n", "let bar = 2\n", "let baz = 3\n"]
        let result = EditorInformation.code(
            in: lines,
            inside: selection,
            ignoreColumns: true
        )
        XCTAssertEqual(result.code, "let foo = 1\nlet bar = 2\n")
        XCTAssertEqual(result.lines, ["let foo = 1\n", "let bar = 2\n"])
    }
}

