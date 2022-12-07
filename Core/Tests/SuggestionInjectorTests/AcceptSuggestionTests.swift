import CopilotModel
import XCTest

@testable import SuggestionInjector

final class AcceptSuggestionTests: XCTestCase {
    func test_accept_suggestion_no_overlap() async throws {
        let content = """
        struct Cat {

        }
        """
        let text = """
            var name: String
            var age: String
        """
        let suggestion = CopilotCompletion(
            text: text,
            position: .init(line: 2, character: 19),
            uuid: "",
            range: .init(
                start: .init(line: 1, character: 0),
                end: .init(line: 2, character: 18)
            ),
            displayText: ""
        )
        var extraInfo = SuggestionInjector.ExtraInfo()
        var lines = content.breakLines()
        var cursor = CursorPosition(line: 0, character: 0)
        SuggestionInjector().acceptSuggestion(
            intoContentWithoutSuggestion: &lines,
            cursorPosition: &cursor,
            completion: suggestion,
            extraInfo: &extraInfo
        )
        XCTAssertTrue(extraInfo.didChangeContent)
        XCTAssertTrue(extraInfo.didChangeCursorPosition)
        XCTAssertNil(extraInfo.suggestionRange)
        XCTAssertEqual(lines, content.breakLines().applying(extraInfo.modifications))
        XCTAssertEqual(cursor, .init(line: 2, character: 19))
        XCTAssertEqual(lines.joined(separator: ""), """
        struct Cat {
            var name: String
            var age: String
        }
        """)
    }

    func test_accept_suggestion_start_from_previous_line() async throws {
        let content = """
        struct Cat {
        }
        """
        let text = """
            var name: String
            var age: String
        """
        let suggestion = CopilotCompletion(
            text: text,
            position: .init(line: 2, character: 19),
            uuid: "",
            range: .init(
                start: .init(line: 1, character: 0),
                end: .init(line: 2, character: 18)
            ),
            displayText: ""
        )

        var extraInfo = SuggestionInjector.ExtraInfo()
        var lines = content.breakLines()
        var cursor = CursorPosition(line: 0, character: 0)
        SuggestionInjector().acceptSuggestion(
            intoContentWithoutSuggestion: &lines,
            cursorPosition: &cursor,
            completion: suggestion,
            extraInfo: &extraInfo
        )
        XCTAssertTrue(extraInfo.didChangeContent)
        XCTAssertTrue(extraInfo.didChangeCursorPosition)
        XCTAssertNil(extraInfo.suggestionRange)
        XCTAssertEqual(lines, content.breakLines().applying(extraInfo.modifications))
        XCTAssertEqual(cursor, .init(line: 2, character: 19))
        XCTAssertEqual(lines.joined(separator: ""), """
        struct Cat {
            var name: String
            var age: String
        }
        """)
    }

    func test_accept_suggestion_overlap() async throws {
        let content = """
        struct Cat {
            var name
        }
        """
        let text = """
            var name: String
            var age: String
        """
        let suggestion = CopilotCompletion(
            text: text,
            position: .init(line: 2, character: 19),
            uuid: "",
            range: .init(
                start: .init(line: 1, character: 0),
                end: .init(line: 2, character: 18)
            ),
            displayText: ""
        )

        var extraInfo = SuggestionInjector.ExtraInfo()
        var lines = content.breakLines()
        var cursor = CursorPosition(line: 0, character: 0)
        SuggestionInjector().acceptSuggestion(
            intoContentWithoutSuggestion: &lines,
            cursorPosition: &cursor,
            completion: suggestion,
            extraInfo: &extraInfo
        )
        XCTAssertTrue(extraInfo.didChangeContent)
        XCTAssertTrue(extraInfo.didChangeCursorPosition)
        XCTAssertNil(extraInfo.suggestionRange)
        XCTAssertEqual(lines, content.breakLines().applying(extraInfo.modifications))
        XCTAssertEqual(cursor, .init(line: 2, character: 19))
        XCTAssertEqual(lines.joined(separator: ""), """
        struct Cat {
            var name: String
            var age: String
        }
        """)
    }

    func test_propose_suggestion_partial_overlap() async throws {
        let content = "func quickSort() {}}\n"
        let text = """
        func quickSort() {
            var array = [1, 3, 2, 4, 5, 6, 7, 8, 9, 10]
            var left = 0
            var right = array.count - 1
            quickSort(&array, left, right)
            print(array)
        }
        """
        let suggestion = CopilotCompletion(
            text: text,
            position: .init(line: 0, character: 0),
            uuid: "",
            range: .init(
                start: .init(line: 0, character: 0),
                end: .init(line: 5, character: 15)
            ),
            displayText: ""
        )

        var extraInfo = SuggestionInjector.ExtraInfo()
        var lines = content.breakLines()
        var cursor = CursorPosition(line: 0, character: 0)
        SuggestionInjector().acceptSuggestion(
            intoContentWithoutSuggestion: &lines,
            cursorPosition: &cursor,
            completion: suggestion,
            extraInfo: &extraInfo
        )
        XCTAssertTrue(extraInfo.didChangeContent)
        XCTAssertTrue(extraInfo.didChangeCursorPosition)
        XCTAssertNil(extraInfo.suggestionRange)
        XCTAssertEqual(lines, content.breakLines().applying(extraInfo.modifications))
        XCTAssertEqual(cursor, .init(line: 6, character: 1))
        XCTAssertEqual(lines.joined(separator: ""), """
        func quickSort() {
            var array = [1, 3, 2, 4, 5, 6, 7, 8, 9, 10]
            var left = 0
            var right = array.count - 1
            quickSort(&array, left, right)
            print(array)
        }

        """)
    }

    func test_no_overlap_append_to_the_end() async throws {
        let content = "func quickSort() {\n"
        let text = """
            var array = [1, 3, 2, 4, 5, 6, 7, 8, 9, 10]
            var left = 0
            var right = array.count - 1
            quickSort(&array, left, right)
            print(array)
        }
        """
        let suggestion = CopilotCompletion(
            text: text,
            position: .init(line: 0, character: 0),
            uuid: "",
            range: .init(
                start: .init(line: 1, character: 0),
                end: .init(line: 5, character: 15)
            ),
            displayText: ""
        )

        var extraInfo = SuggestionInjector.ExtraInfo()
        var lines = content.breakLines()
        var cursor = CursorPosition(line: 0, character: 0)
        SuggestionInjector().acceptSuggestion(
            intoContentWithoutSuggestion: &lines,
            cursorPosition: &cursor,
            completion: suggestion,
            extraInfo: &extraInfo
        )
        XCTAssertTrue(extraInfo.didChangeContent)
        XCTAssertTrue(extraInfo.didChangeCursorPosition)
        XCTAssertNil(extraInfo.suggestionRange)
        XCTAssertEqual(lines, content.breakLines().applying(extraInfo.modifications))
        XCTAssertEqual(cursor, .init(line: 6, character: 1))
        XCTAssertEqual(lines.joined(separator: ""), """
        func quickSort() {
            var array = [1, 3, 2, 4, 5, 6, 7, 8, 9, 10]
            var left = 0
            var right = array.count - 1
            quickSort(&array, left, right)
            print(array)
        }

        """)
    }
}
