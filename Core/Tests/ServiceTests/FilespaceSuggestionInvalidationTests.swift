import Foundation
import SuggestionModel
import XCTest

@testable import Workspace
@testable import Service

class FilespaceSuggestionInvalidationTests: XCTestCase {
    @WorkspaceActor
    func prepare(suggestionText: String, cursorPosition: CursorPosition) async throws -> Filespace {
        let pool = WorkspacePool()
        let (_, filespace) = try await pool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: URL(fileURLWithPath: "file/path/to.swift"))
        filespace.suggestions = [
            .init(
                id: "",
                text: suggestionText,
                position: cursorPosition,
                range: .outOfScope
            ),
        ]
        return filespace
    }

    func test_text_typing_suggestion_should_be_valid() async throws {
        let filespace = try await prepare(
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 0)
        )
        let isValid = await filespace.validateSuggestions(
            lines: ["\n", "hell\n", "\n"],
            cursorPosition: .init(line: 1, character: 4)
        )
        XCTAssertTrue(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNotNil(suggestion)
    }

    func test_text_typing_suggestion_in_the_middle_should_be_valid() async throws {
        let filespace = try await prepare(
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 0)
        )
        let isValid = await filespace.validateSuggestions(
            lines: ["\n", "hell man\n", "\n"],
            cursorPosition: .init(line: 1, character: 4)
        )
        XCTAssertTrue(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNotNil(suggestion)
    }

    func test_text_cursor_moved_to_another_line_should_invalidate() async throws {
        let filespace = try await prepare(
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 0)
        )
        let isValid = await filespace.validateSuggestions(
            lines: ["\n", "hell\n", "\n"],
            cursorPosition: .init(line: 2, character: 0)
        )
        XCTAssertFalse(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNil(suggestion)
    }

    func test_text_cursor_is_invalid_should_invalidate() async throws {
        let filespace = try await prepare(
            suggestionText: "hello man",
            cursorPosition: .init(line: 100, character: 0)
        )
        let isValid = await filespace.validateSuggestions(
            lines: ["\n", "hell\n", "\n"],
            cursorPosition: .init(line: 100, character: 4)
        )
        XCTAssertFalse(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNil(suggestion)
    }

    func test_line_content_does_not_match_input_should_invalidate() async throws {
        let filespace = try await prepare(
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 0)
        )
        let isValid = await filespace.validateSuggestions(
            lines: ["\n", "helo\n", "\n"],
            cursorPosition: .init(line: 1, character: 4)
        )
        XCTAssertFalse(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNil(suggestion)
    }

    func test_line_content_does_not_match_input_should_invalidate_index_out_of_scope() async throws {
        let filespace = try await prepare(
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 0)
        )
        let isValid = await filespace.validateSuggestions(
            lines: ["\n", "helo\n", "\n"],
            cursorPosition: .init(line: 1, character: 100)
        )
        XCTAssertFalse(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNil(suggestion)
    }

    func test_finish_typing_the_whole_single_line_suggestion_should_invalidate() async throws {
        let filespace = try await prepare(
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 0)
        )
        let isValid = await filespace.validateSuggestions(
            lines: ["\n", "hello man\n", "\n"],
            cursorPosition: .init(line: 1, character: 9)
        )
        XCTAssertFalse(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNil(suggestion)
    }

    func test_finish_typing_the_whole_single_line_suggestion_suggestion_is_incomplete_should_invalidate(
    ) async throws {
        let filespace = try await prepare(
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 0)
        )
        let isValid = await filespace.validateSuggestions(
            lines: ["\n", "hello man!!!!!\n", "\n"],
            cursorPosition: .init(line: 1, character: 9)
        )
        XCTAssertFalse(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNil(suggestion)
    }

    func test_finish_typing_the_whole_multiple_line_suggestion_should_be_valid() async throws {
        let filespace = try await prepare(
            suggestionText: "hello man\nhow are you?",
            cursorPosition: .init(line: 1, character: 0)
        )
        let isValid = await filespace.validateSuggestions(
            lines: ["\n", "hello man\n", "\n"],
            cursorPosition: .init(line: 1, character: 9)
        )
        XCTAssertTrue(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNotNil(suggestion)
    }

    func test_undo_text_to_a_state_before_the_suggestion_was_generated_should_invalidate(
    ) async throws {
        let filespace = try await prepare(
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 5) // generating man from hello
        )
        let isValid = await filespace.validateSuggestions(
            lines: ["\n", "hell\n", "\n"],
            cursorPosition: .init(line: 1, character: 4)
        )
        XCTAssertFalse(isValid)
        let suggestion = filespace.presentingSuggestion
        XCTAssertNil(suggestion)
    }
}

