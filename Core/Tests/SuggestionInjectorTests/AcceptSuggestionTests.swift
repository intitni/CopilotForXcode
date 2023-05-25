import SuggestionModel
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
        let suggestion = CodeSuggestion(
            text: text,
            position: .init(line: 0, character: 1),
            uuid: "",
            range: .init(
                start: .init(line: 1, character: 0),
                end: .init(line: 1, character: 0)
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
        struct Cat {
            var name: String
            var age: String
        """
        let suggestion = CodeSuggestion(
            text: text,
            position: .init(line: 0, character: 12),
            uuid: "",
            range: .init(
                start: .init(line: 0, character: 0),
                end: .init(line: 0, character: 12)
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
        let suggestion = CodeSuggestion(
            text: text,
            position: .init(line: 1, character: 12),
            uuid: "",
            range: .init(
                start: .init(line: 1, character: 0),
                end: .init(line: 1, character: 12)
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
    
    func test_accept_suggestion_overlap_continue_typing() async throws {
        let content = """
        struct Cat {
            var name: Str
        }
        """
        let text = """
            var name: String
            var age: String
        """
        let suggestion = CodeSuggestion(
            text: text,
            position: .init(line: 1, character: 12),
            uuid: "",
            range: .init(
                start: .init(line: 1, character: 0),
                end: .init(line: 1, character: 12)
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
        let suggestion = CodeSuggestion(
            text: text,
            position: .init(line: 0, character: 18),
            uuid: "",
            range: .init(
                start: .init(line: 0, character: 0),
                end: .init(line: 0, character: 20)
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
        let suggestion = CodeSuggestion(
            text: text,
            position: .init(line: 0, character: 18),
            uuid: "",
            range: .init(
                start: .init(line: 1, character: 0),
                end: .init(line: 1, character: 0)
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
    
    func test_replacing_multiple_lines() async throws {
        let content = """
        struct Cat {
            func speak() { print("meow") }
        }
        """
        let text = """
        struct Dog {
            func speak() {
                print("woof")
            }
        }
        """
        let suggestion = CodeSuggestion(
            text: text,
            position: .init(line: 0, character: 7),
            uuid: "",
            range: .init(
                start: .init(line: 0, character: 0),
                end: .init(line: 2, character: 1)
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
        XCTAssertEqual(cursor, .init(line: 4, character: 1))
        XCTAssertEqual(lines.joined(separator: ""), text)
    }
    
    func test_replacing_multiple_lines_in_the_middle() async throws {
        let content = """
        protocol Animal {
            func speak()
        }
        
        struct Cat: Animal {
            func speak() { print("meow") }
        }
        
        func foo() {}
        """
        let text = """
        Dog {
            func speak() {
                print("woof")
            }
        """
        let suggestion = CodeSuggestion(
            text: text,
            position: .init(line: 5, character: 34),
            uuid: "",
            range: .init(
                start: .init(line: 4, character: 7),
                end: .init(line: 5, character: 34)
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
        XCTAssertEqual(cursor, .init(line: 7, character: 5))
        XCTAssertEqual(lines.joined(separator: ""), """
        protocol Animal {
            func speak()
        }
        
        struct Dog {
            func speak() {
                print("woof")
            }
        }
        
        func foo() {}
        """)
    }
}
