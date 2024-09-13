import Foundation
import SuggestionBasic
import XCTest

@testable import Service
@testable import Workspace

class FilespaceSuggestionInvalidationTests: XCTestCase {
    @WorkspaceActor
    func prepare(
        lines: [String],
        suggestionText: String,
        cursorPosition: CursorPosition,
        range: CursorRange
    ) async throws -> Filespace {
        let pool = WorkspacePool()
        let (_, filespace) = try await pool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: URL(fileURLWithPath: "file/path/to.swift"))
        filespace.suggestions = [
            .init(
                id: "",
                text: suggestionText,
                position: cursorPosition,
                range: range
            ),
        ]
        filespace.suggestionSourceSnapshot = .init(lines: lines, cursorPosition: cursorPosition)
        return filespace
    }

    func test_text_typing_suggestion_should_be_valid() async throws {
        let lines = ["\n", "hell\n", "\n"]
        let filespace = try await prepare(
            lines: lines,
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 0),
            range: .init(startPair: (1, 0), endPair: (1, 0))
        )
        let isValid = await filespace.validateSuggestions(
            lines: lines,
            cursorPosition: .init(line: 1, character: 4),
            alwaysTrueIfCursorNotMoved: false // TODO: What
        )
        XCTAssertTrue(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNotNil(suggestion)
    }

    func test_text_typing_suggestion_in_the_middle_should_be_valid() async throws {
        let lines = ["\n", "hell man\n", "\n"]
        let filespace = try await prepare(
            lines: lines,
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 0),
            range: .init(startPair: (1, 0), endPair: (1, 0))
        )
        let isValid = await filespace.validateSuggestions(
            lines: lines,
            cursorPosition: .init(line: 1, character: 4),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNotNil(suggestion)
    }

    func test_text_typing_suggestion_with_emoji_in_the_middle_should_be_valid() async throws {
        let lines = ["\n", "hell🎆🎆 man\n", "\n"]
        let filespace = try await prepare(
            lines: lines,
            suggestionText: "hello🎆🎆 man",
            cursorPosition: .init(line: 1, character: 0),
            range: .init(startPair: (1, 0), endPair: (1, 0))
        )
        let isValid = await filespace.validateSuggestions(
            lines: lines,
            cursorPosition: .init(line: 1, character: 4),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNotNil(suggestion)
    }

    func test_text_typing_suggestion_typed_emoji_in_the_middle_should_be_valid() async throws {
        let lines = ["\n", "h🎆🎆o ma\n", "\n"]
        let filespace = try await prepare(
            lines: lines,
            suggestionText: "h🎆🎆o man",
            cursorPosition: .init(line: 1, character: 0),
            range: .init(startPair: (1, 0), endPair: (1, 0))
        )
        let isValid = await filespace.validateSuggestions(
            lines: lines,
            cursorPosition: .init(line: 1, character: 2),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNotNil(suggestion)
    }

    func test_text_typing_suggestion_cutting_emoji_in_the_middle_should_be_valid() async throws {
        // undefined behavior, must not crash

        let lines = ["\n", "h🎆🎆o ma\n", "\n"]

        let filespace = try await prepare(
            lines: lines,
            suggestionText: "h🎆🎆o man",
            cursorPosition: .init(line: 1, character: 0),
            range: .init(startPair: (1, 0), endPair: (1, 0))
        )
        let isValid = await filespace.validateSuggestions(
            lines: lines,
            cursorPosition: .init(line: 1, character: 3),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNotNil(suggestion)
    }
    
    func test_typing_not_according_to_suggestion_should_invalidate() async throws {
        let lines = ["\n", "hello ma\n", "\n"]
        let filespace = try await prepare(
            lines: lines,
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 8),
            range: .init(startPair: (1, 0), endPair: (1, 8))
        )
        let wasValid = await filespace.validateSuggestions(
            lines: lines,
            cursorPosition: .init(line: 1, character: 8),
            alwaysTrueIfCursorNotMoved: false
        )
        let isValid = await filespace.validateSuggestions(
            lines: ["\n", "hello mat\n", "\n"],
            cursorPosition: .init(line: 1, character: 9),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(wasValid)
        XCTAssertFalse(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNil(suggestion)
    }

    func test_text_cursor_moved_to_another_line_should_invalidate() async throws {
        let lines = ["\n", "hell\n", "\n"]
        let filespace = try await prepare(
            lines: lines,
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 0),
            range: .init(startPair: (1, 0), endPair: (1, 0))
        )
        let isValid = await filespace.validateSuggestions(
            lines: lines,
            cursorPosition: .init(line: 2, character: 0),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertFalse(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNil(suggestion)
    }

    func test_text_cursor_is_invalid_should_invalidate() async throws {
        let lines = ["\n", "hell\n", "\n"]
        let filespace = try await prepare(
            lines: lines,
            suggestionText: "hello man",
            cursorPosition: .init(line: 100, character: 0),
            range: .init(startPair: (1, 0), endPair: (1, 0))
        )
        let isValid = await filespace.validateSuggestions(
            lines: lines,
            cursorPosition: .init(line: 100, character: 4),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertFalse(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNil(suggestion)
    }

    func test_line_content_does_not_match_input_should_invalidate() async throws {
        let filespace = try await prepare(
            lines: ["\n", "hello\n", "\n"],
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 5),
            range: .init(startPair: (1, 0), endPair: (1, 5))
        )
        let isValid = await filespace.validateSuggestions(
            lines: ["\n", "helo\n", "\n"],
            cursorPosition: .init(line: 1, character: 4),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertFalse(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNil(suggestion)
    }

    func test_line_content_does_not_match_input_should_invalidate_index_out_of_scope() async throws {
        let filespace = try await prepare(
            lines: ["\n", "hello\n", "\n"],
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 5),
            range: .init(startPair: (1, 0), endPair: (1, 5))
        )
        let isValid = await filespace.validateSuggestions(
            lines: ["\n", "helo\n", "\n"],
            cursorPosition: .init(line: 1, character: 100),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertFalse(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNil(suggestion)
    }

    func test_finish_typing_the_whole_single_line_suggestion_should_invalidate() async throws {
        let lines = ["\n", "hello ma\n", "\n"]
        let filespace = try await prepare(
            lines: lines,
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 8),
            range: .init(startPair: (1, 0), endPair: (1, 8))
        )
        let wasValid = await filespace.validateSuggestions(
            lines: lines,
            cursorPosition: .init(line: 1, character: 8),
            alwaysTrueIfCursorNotMoved: false
        )
        let isValid = await filespace.validateSuggestions(
            lines: ["\n", "hello man\n", "\n"],
            cursorPosition: .init(line: 1, character: 9),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(wasValid)
        XCTAssertFalse(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNil(suggestion)
    }

    func test_finish_typing_the_whole_single_line_suggestion_with_emoji_should_invalidate(
    ) async throws {
        let lines = ["\n", "hello m🎆🎆a\n", "\n"]
        let filespace = try await prepare(
            lines: lines,
            suggestionText: "hello m🎆🎆an",
            cursorPosition: .init(line: 1, character: 0),
            range: .init(startPair: (1, 0), endPair: (1, 0))
        )
        let wasValid = await filespace.validateSuggestions(
            lines: lines,
            cursorPosition: .init(line: 1, character: 12),
            alwaysTrueIfCursorNotMoved: false
        )
        let isValid = await filespace.validateSuggestions(
            lines: ["\n", "hello m🎆🎆an\n", "\n"],
            cursorPosition: .init(line: 1, character: 13),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(wasValid)
        XCTAssertFalse(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNil(suggestion)
    }

    func test_finish_typing_the_whole_single_line_suggestion_suggestion_is_incomplete_should_invalidate(
    ) async throws {
        let lines = ["\n", "hello ma!!!!\n", "\n"]
        let filespace = try await prepare(
            lines: lines,
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 0),
            range: .init(startPair: (1, 0), endPair: (1, 0))
        )
        let wasValid = await filespace.validateSuggestions(
            lines: lines,
            cursorPosition: .init(line: 1, character: 8),
            alwaysTrueIfCursorNotMoved: false
        )
        let isValid = await filespace.validateSuggestions(
            lines: ["\n", "hello man!!!!!\n", "\n"],
            cursorPosition: .init(line: 1, character: 9),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(wasValid)
        XCTAssertFalse(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNil(suggestion)
    }

    func test_finish_typing_the_whole_multiple_line_suggestion_should_be_valid() async throws {
        let lines = ["\n", "hello man\n", "\n"]
        let filespace = try await prepare(
            lines: lines,
            suggestionText: "hello man\nhow are you?",
            cursorPosition: .init(line: 1, character: 0),
            range: .init(startPair: (1, 0), endPair: (1, 0))
        )
        let isValid = await filespace.validateSuggestions(
            lines: lines,
            cursorPosition: .init(line: 1, character: 9),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNotNil(suggestion)
    }

    func test_finish_typing_the_whole_multiple_line_suggestion_with_emoji_should_be_valid(
    ) async throws {
        let lines = ["\n", "hello m🎆🎆an\n", "\n"]
        let filespace = try await prepare(
            lines: lines,
            suggestionText: "hello m🎆🎆an\nhow are you?",
            cursorPosition: .init(line: 1, character: 0),
            range: .init(startPair: (1, 0), endPair: (1, 0))
        )
        let isValid = await filespace.validateSuggestions(
            lines: lines,
            cursorPosition: .init(line: 1, character: 13),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNotNil(suggestion)
    }

    func test_undo_text_to_a_state_before_the_suggestion_was_generated_should_invalidate(
    ) async throws {
        let lines = ["\n", "hell\n", "\n"]
        let filespace = try await prepare(
            lines: lines,
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 5), // generating man from hello
            range: .init(startPair: (1, 0), endPair: (1, 5))
        )
        let isValid = await filespace.validateSuggestions(
            lines: lines,
            cursorPosition: .init(line: 1, character: 4),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertFalse(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNil(suggestion)
    }

    func test_rewriting_the_current_line_by_removing_the_suffix_should_be_valid() async throws {
        let lines = ["hello world !!!\n"]
        let filespace = try await prepare(
            lines: lines,
            suggestionText: "hello world",
            cursorPosition: .init(line: 0, character: 15),
            range: .init(startPair: (0, 0), endPair: (0, 15))
        )
        let isValid = await filespace.validateSuggestions(
            lines: lines,
            cursorPosition: .init(line: 0, character: 15),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNotNil(suggestion)
    }

    func test_rewriting_the_current_line_should_be_valid() async throws {
        let lines = ["hello everyone !!!\n"]
        let filespace = try await prepare(
            lines: lines,
            suggestionText: "hello world !!!",
            cursorPosition: .init(line: 0, character: 18),
            range: .init(startPair: (0, 0), endPair: (0, 18))
        )
        let isValid = await filespace.validateSuggestions(
            lines: lines,
            cursorPosition: .init(line: 0, character: 18),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNotNil(suggestion)
    }
}

