import Foundation
import SuggestionBasic
import XCTest

@testable import Service
@testable import Workspace
@testable import WorkspaceSuggestionService

class FilespaceSuggestionDefaultProviderInvalidationTests: XCTestCase {
    @WorkspaceActor
    func prepare(
        lines: [String],
        suggestionText: String,
        cursorPosition: CursorPosition,
        range: CursorRange,
        effectiveRange: CodeSuggestion.EffectiveRange = .line
    ) async throws -> DefaultFilespaceSuggestionProvider {
        let provider = DefaultFilespaceSuggestionProvider()
        provider.suggestionSourceSnapshot = .init(lines: lines, cursorPosition: cursorPosition)
        provider.codeSuggestions = [
            .init(
                id: "1",
                text: suggestionText,
                position: cursorPosition,
                range: range,
                effectiveRange: effectiveRange
            ),
        ]
        return provider
    }

    func test_text_typing_suggestion_should_be_valid() async throws {
        let lines = ["\n", "hell\n", "\n"]
        let provider = try await prepare(
            lines: lines,
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 0),
            range: .init(startPair: (1, 0), endPair: (1, 0))
        )
        let isValid = await provider.validateSuggestions(
            displayedSuggestionIds: ["1"],
            lines: lines,
            cursorPosition: .init(line: 1, character: 4),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(isValid)
        let isEmpty = await provider.codeSuggestions.isEmpty
        XCTAssertTrue(!isEmpty)
    }

    func test_text_typing_suggestion_in_the_middle_should_be_valid() async throws {
        let lines = ["\n", "hell man\n", "\n"]
        let provider = try await prepare(
            lines: lines,
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 0),
            range: .init(startPair: (1, 0), endPair: (1, 0))
        )
        let isValid = await provider.validateSuggestions(
            displayedSuggestionIds: ["1"],
            lines: lines,
            cursorPosition: .init(line: 1, character: 4),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(isValid)
        let isEmpty = await provider.codeSuggestions.isEmpty
        XCTAssertTrue(!isEmpty)
    }

    func test_text_typing_suggestion_with_emoji_in_the_middle_should_be_valid() async throws {
        let lines = ["\n", "hell🎆🎆 man\n", "\n"]
        let provider = try await prepare(
            lines: lines,
            suggestionText: "hello🎆🎆 man",
            cursorPosition: .init(line: 1, character: 0),
            range: .init(startPair: (1, 0), endPair: (1, 0))
        )
        let isValid = await provider.validateSuggestions(
            displayedSuggestionIds: ["1"],
            lines: lines,
            cursorPosition: .init(line: 1, character: 4),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(isValid)
        let isEmpty = await provider.codeSuggestions.isEmpty
        XCTAssertTrue(!isEmpty)
    }

    func test_text_typing_suggestion_typed_emoji_in_the_middle_should_be_valid() async throws {
        let lines = ["\n", "h🎆🎆o ma\n", "\n"]
        let provider = try await prepare(
            lines: lines,
            suggestionText: "h🎆🎆o man",
            cursorPosition: .init(line: 1, character: 0),
            range: .init(startPair: (1, 0), endPair: (1, 0))
        )
        let isValid = await provider.validateSuggestions(
            displayedSuggestionIds: ["1"],
            lines: lines,
            cursorPosition: .init(line: 1, character: 2),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(isValid)
        let isEmpty = await provider.codeSuggestions.isEmpty
        XCTAssertTrue(!isEmpty)
    }

    func test_text_typing_suggestion_cutting_emoji_in_the_middle_should_be_valid() async throws {
        let lines = ["\n", "h🎆🎆o ma\n", "\n"]
        let provider = try await prepare(
            lines: lines,
            suggestionText: "h🎆🎆o man",
            cursorPosition: .init(line: 1, character: 0),
            range: .init(startPair: (1, 0), endPair: (1, 0))
        )
        let isValid = await provider.validateSuggestions(
            displayedSuggestionIds: ["1"],
            lines: lines,
            cursorPosition: .init(line: 1, character: 3),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(isValid)
        let isEmpty = await provider.codeSuggestions.isEmpty
        let isSnapshotReset = await provider.suggestionSourceSnapshot == .default
        XCTAssertFalse(isEmpty)
        XCTAssertFalse(isSnapshotReset)
    }

    func test_typing_not_according_to_suggestion_should_invalidate() async throws {
        let lines = ["\n", "hello ma\n", "\n"]
        let provider = try await prepare(
            lines: lines,
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 8),
            range: .init(startPair: (1, 0), endPair: (1, 8))
        )
        let wasValid = await provider.validateSuggestions(
            displayedSuggestionIds: ["1"],
            lines: lines,
            cursorPosition: .init(line: 1, character: 8),
            alwaysTrueIfCursorNotMoved: false
        )
        let isValid = await provider.validateSuggestions(
            displayedSuggestionIds: ["1"],
            lines: ["\n", "hello mat\n", "\n"],
            cursorPosition: .init(line: 1, character: 9),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(wasValid)
        XCTAssertFalse(isValid)
        let isEmpty = await provider.codeSuggestions.isEmpty
        let isSnapshotReset = await provider.suggestionSourceSnapshot == .default
        XCTAssertTrue(isEmpty)
        XCTAssertTrue(isSnapshotReset)
    }

    func test_text_cursor_moved_to_another_line_should_invalidate() async throws {
        let lines = ["\n", "hell\n", "\n"]
        let provider = try await prepare(
            lines: lines,
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 0),
            range: .init(startPair: (1, 0), endPair: (1, 0))
        )
        let isValid = await provider.validateSuggestions(
            displayedSuggestionIds: ["1"],
            lines: lines,
            cursorPosition: .init(line: 2, character: 0),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertFalse(isValid)
        let isEmpty = await provider.codeSuggestions.isEmpty
        XCTAssertTrue(isEmpty)
    }

    func test_text_cursor_is_invalid_should_invalidate() async throws {
        let lines = ["\n", "hell\n", "\n"]
        let provider = try await prepare(
            lines: lines,
            suggestionText: "hello man",
            cursorPosition: .init(line: 100, character: 0),
            range: .init(startPair: (1, 0), endPair: (1, 0))
        )
        let isValid = await provider.validateSuggestions(
            displayedSuggestionIds: ["1"],
            lines: lines,
            cursorPosition: .init(line: 100, character: 4),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertFalse(isValid)
        let isEmpty = await provider.codeSuggestions.isEmpty
        XCTAssertTrue(isEmpty)
    }

    func test_line_content_does_not_match_input_should_invalidate() async throws {
        let provider = try await prepare(
            lines: ["\n", "hello\n", "\n"],
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 5),
            range: .init(startPair: (1, 0), endPair: (1, 5))
        )
        let isValid = await provider.validateSuggestions(
            displayedSuggestionIds: ["1"],
            lines: ["\n", "helo\n", "\n"],
            cursorPosition: .init(line: 1, character: 4),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertFalse(isValid)
        let isEmpty = await provider.codeSuggestions.isEmpty
        XCTAssertTrue(isEmpty)
    }

    func test_line_content_does_not_match_input_should_invalidate_index_out_of_scope() async throws {
        let provider = try await prepare(
            lines: ["\n", "hello\n", "\n"],
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 5),
            range: .init(startPair: (1, 0), endPair: (1, 5))
        )
        let isValid = await provider.validateSuggestions(
            displayedSuggestionIds: ["1"],
            lines: ["\n", "helo\n", "\n"],
            cursorPosition: .init(line: 1, character: 100),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertFalse(isValid)
        let isEmpty = await provider.codeSuggestions.isEmpty
        XCTAssertTrue(isEmpty)
    }

    func test_finish_typing_the_whole_single_line_suggestion_should_invalidate() async throws {
        let lines = ["\n", "hello ma\n", "\n"]
        let provider = try await prepare(
            lines: lines,
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 8),
            range: .init(startPair: (1, 0), endPair: (1, 8))
        )
        let wasValid = await provider.validateSuggestions(
            displayedSuggestionIds: ["1"],
            lines: lines,
            cursorPosition: .init(line: 1, character: 8),
            alwaysTrueIfCursorNotMoved: false
        )
        let isValid = await provider.validateSuggestions(
            displayedSuggestionIds: ["1"],
            lines: ["\n", "hello man\n", "\n"],
            cursorPosition: .init(line: 1, character: 9),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(wasValid)
        XCTAssertFalse(isValid)
        let isEmpty = await provider.codeSuggestions.isEmpty
        XCTAssertTrue(isEmpty)
    }

    func test_finish_typing_the_whole_single_line_suggestion_with_emoji_should_invalidate(
    ) async throws {
        let lines = ["\n", "hello m🎆🎆a\n", "\n"]
        let provider = try await prepare(
            lines: lines,
            suggestionText: "hello m🎆🎆an",
            cursorPosition: .init(line: 1, character: 0),
            range: .init(startPair: (1, 0), endPair: (1, 0))
        )
        let wasValid = await provider.validateSuggestions(
            displayedSuggestionIds: ["1"],
            lines: lines,
            cursorPosition: .init(line: 1, character: 12),
            alwaysTrueIfCursorNotMoved: false
        )
        let isValid = await provider.validateSuggestions(
            displayedSuggestionIds: ["1"],
            lines: ["\n", "hello m🎆🎆an\n", "\n"],
            cursorPosition: .init(line: 1, character: 13),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(wasValid)
        XCTAssertFalse(isValid)
        let isEmpty = await provider.codeSuggestions.isEmpty
        XCTAssertTrue(isEmpty)
    }

    func test_finish_typing_the_whole_single_line_suggestion_suggestion_is_incomplete_should_invalidate(
    ) async throws {
        let lines = ["\n", "hello ma!!!!\n", "\n"]
        let provider = try await prepare(
            lines: lines,
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 0),
            range: .init(startPair: (1, 0), endPair: (1, 0))
        )
        let wasValid = await provider.validateSuggestions(
            displayedSuggestionIds: ["1"],
            lines: lines,
            cursorPosition: .init(line: 1, character: 8),
            alwaysTrueIfCursorNotMoved: false
        )
        let isValid = await provider.validateSuggestions(
            displayedSuggestionIds: ["1"],
            lines: ["\n", "hello man!!!!!\n", "\n"],
            cursorPosition: .init(line: 1, character: 9),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(wasValid)
        XCTAssertFalse(isValid)
        let isEmpty = await provider.codeSuggestions.isEmpty
        XCTAssertTrue(isEmpty)
    }

    func test_finish_typing_the_whole_multiple_line_suggestion_should_be_valid() async throws {
        let lines = ["\n", "hello man\n", "\n"]
        let provider = try await prepare(
            lines: lines,
            suggestionText: "hello man\nhow are you?",
            cursorPosition: .init(line: 1, character: 0),
            range: .init(startPair: (1, 0), endPair: (1, 0))
        )
        let isValid = await provider.validateSuggestions(
            displayedSuggestionIds: ["1"],
            lines: lines,
            cursorPosition: .init(line: 1, character: 9),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(isValid)
        let isEmpty = await provider.codeSuggestions.isEmpty
        XCTAssertFalse(isEmpty)
    }

    func test_finish_typing_the_whole_multiple_line_suggestion_with_emoji_should_be_valid(
    ) async throws {
        let lines = ["\n", "hello m🎆🎆an\n", "\n"]
        let provider = try await prepare(
            lines: lines,
            suggestionText: "hello m🎆🎆an\nhow are you?",
            cursorPosition: .init(line: 1, character: 0),
            range: .init(startPair: (1, 0), endPair: (1, 0))
        )
        let isValid = await provider.validateSuggestions(
            displayedSuggestionIds: ["1"],
            lines: lines,
            cursorPosition: .init(line: 1, character: 13),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(isValid)
        let isEmpty = await provider.codeSuggestions.isEmpty
        XCTAssertFalse(isEmpty)
    }

    func test_undo_text_to_a_state_before_the_suggestion_was_generated_should_invalidate(
    ) async throws {
        let lines = ["\n", "hell\n", "\n"]
        let provider = try await prepare(
            lines: lines,
            suggestionText: "hello man",
            cursorPosition: .init(line: 1, character: 5),
            range: .init(startPair: (1, 0), endPair: (1, 5))
        )
        let isValid = await provider.validateSuggestions(
            displayedSuggestionIds: ["1"],
            lines: lines,
            cursorPosition: .init(line: 1, character: 4),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertFalse(isValid)
        let isEmpty = await provider.codeSuggestions.isEmpty
        XCTAssertTrue(isEmpty)
    }

    func test_rewriting_the_current_line_by_removing_the_suffix_should_be_valid() async throws {
        let lines = ["hello world !!!\n"]
        let provider = try await prepare(
            lines: lines,
            suggestionText: "hello world",
            cursorPosition: .init(line: 0, character: 15),
            range: .init(startPair: (0, 0), endPair: (0, 15))
        )
        let isValid = await provider.validateSuggestions(
            displayedSuggestionIds: ["1"],
            lines: lines,
            cursorPosition: .init(line: 0, character: 15),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(isValid)
        let isEmpty = await provider.codeSuggestions.isEmpty
        XCTAssertFalse(isEmpty)
    }

    func test_rewriting_the_current_line_should_be_valid() async throws {
        let lines = ["hello everyone !!!\n"]
        let provider = try await prepare(
            lines: lines,
            suggestionText: "hello world !!!",
            cursorPosition: .init(line: 0, character: 18),
            range: .init(startPair: (0, 0), endPair: (0, 18))
        )
        let isValid = await provider.validateSuggestions(
            displayedSuggestionIds: ["1"],
            lines: lines,
            cursorPosition: .init(line: 0, character: 18),
            alwaysTrueIfCursorNotMoved: false
        )
        XCTAssertTrue(isValid)
        let isEmpty = await provider.codeSuggestions.isEmpty
        XCTAssertFalse(isEmpty)
    }
}

