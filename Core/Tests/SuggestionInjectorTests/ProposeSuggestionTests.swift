//import SuggestionBasic
//import XCTest
//
//@testable import SuggestionInjector
//
//final class ProposeSuggestionTests: XCTestCase {
//    func test_propose_suggestion_no_overlap() async throws {
//        let content = """
//        struct Cat {
//
//        }
//        """
//        let text = """
//            var name: String
//            var age: String
//        """
//        let suggestion = CodeSuggestion(
//            id: "",
//            text: text,
//            position: .init(line: 2, character: 19),
//            range: .init(
//                start: .init(line: 1, character: 0),
//                end: .init(line: 2, character: 18)
//            )
//        )
//        var extraInfo = SuggestionInjector.ExtraInfo()
//        var lines = content.breakLines()
//        SuggestionInjector().proposeSuggestion(
//            intoContentWithoutSuggestion: &lines,
//            completion: suggestion,
//            index: 0,
//            count: 10,
//            extraInfo: &extraInfo
//        )
//        XCTAssertTrue(extraInfo.didChangeContent)
//        XCTAssertFalse(extraInfo.didChangeCursorPosition)
//        XCTAssertEqual(extraInfo.suggestionRange, 2...5)
//        XCTAssertEqual(lines, content.breakLines().applying(extraInfo.modifications))
//        XCTAssertEqual(
//            lines.joined(separator: ""),
//            """
//            struct Cat {
//
//            /*========== Copilot Suggestion 1/10
//                var name: String
//                var age: String
//            *///======== End of Copilot Suggestion
//            }
//            """,
//            "The user may want to keep typing on the empty line, so suggestion is addded to the next line"
//        )
//    }
//
//    func test_propose_suggestion_no_overlap_start_from_previous_line() async throws {
//        let content = """
//        struct Cat {
//        }
//        """
//        let text = """
//            var name: String
//            var age: String
//        """
//        let suggestion = CodeSuggestion(
//            id: "",
//            text: text,
//            position: .init(line: 1, character: 0),
//            range: .init(
//                start: .init(line: 1, character: 0),
//                end: .init(line: 2, character: 18)
//            )
//        )
//        var extraInfo = SuggestionInjector.ExtraInfo()
//        var lines = content.breakLines()
//        SuggestionInjector().proposeSuggestion(
//            intoContentWithoutSuggestion: &lines,
//            completion: suggestion,
//            index: 0,
//            count: 10,
//            extraInfo: &extraInfo
//        )
//        XCTAssertTrue(extraInfo.didChangeContent)
//        XCTAssertFalse(extraInfo.didChangeCursorPosition)
//        XCTAssertEqual(extraInfo.suggestionRange, 1...4)
//        XCTAssertEqual(lines, content.breakLines().applying(extraInfo.modifications))
//        XCTAssertEqual(lines.joined(separator: ""), """
//        struct Cat {
//        /*========== Copilot Suggestion 1/10
//            var name: String
//            var age: String
//        *///======== End of Copilot Suggestion
//        }
//        """)
//    }
//
//    func test_propose_suggestion_overlap() async throws {
//        let content = """
//        struct Cat {
//            var name
//        }
//        """
//        let text = """
//            var name: String
//            var age: String
//        """
//        let suggestion = CodeSuggestion(
//            id: "",
//            text: text,
//            position: .init(line: 1, character: 0),
//            range: .init(
//                start: .init(line: 1, character: 0),
//                end: .init(line: 2, character: 18)
//            )
//        )
//        var extraInfo = SuggestionInjector.ExtraInfo()
//        var lines = content.breakLines()
//        SuggestionInjector().proposeSuggestion(
//            intoContentWithoutSuggestion: &lines,
//            completion: suggestion,
//            index: 0,
//            count: 10,
//            extraInfo: &extraInfo
//        )
//        XCTAssertTrue(extraInfo.didChangeContent)
//        XCTAssertFalse(extraInfo.didChangeCursorPosition)
//        XCTAssertEqual(extraInfo.suggestionRange, 2...5)
//        XCTAssertEqual(lines, content.breakLines().applying(extraInfo.modifications))
//        XCTAssertEqual(lines.joined(separator: ""), """
//        struct Cat {
//            var name
//        /*========== Copilot Suggestion 1/10
//                   ^: String
//            var age: String
//        *///======== End of Copilot Suggestion
//        }
//        """)
//    }
//
//    func test_propose_suggestion_overlap_first_line_is_empty() async throws {
//        let content = """
//        struct Cat {
//            var name: String
//        }
//        """
//        let text = """
//            var name: String
//            var age: String
//        """
//        let suggestion = CodeSuggestion(
//            id: "",
//            text: text,
//            position: .init(line: 1, character: 0),
//            range: .init(
//                start: .init(line: 1, character: 0),
//                end: .init(line: 2, character: 18)
//            )
//        )
//        var extraInfo = SuggestionInjector.ExtraInfo()
//        var lines = content.breakLines()
//        SuggestionInjector().proposeSuggestion(
//            intoContentWithoutSuggestion: &lines,
//            completion: suggestion,
//            index: 0,
//            count: 10,
//            extraInfo: &extraInfo
//        )
//        XCTAssertTrue(extraInfo.didChangeContent)
//        XCTAssertFalse(extraInfo.didChangeCursorPosition)
//        XCTAssertEqual(extraInfo.suggestionRange, 2...5)
//        XCTAssertEqual(lines, content.breakLines().applying(extraInfo.modifications))
//        XCTAssertEqual(lines.joined(separator: ""), """
//        struct Cat {
//            var name: String
//        /*========== Copilot Suggestion 1/10
//                           ^
//            var age: String
//        *///======== End of Copilot Suggestion
//        }
//        """)
//    }
//
//    // swiftformat:disable indent trailingSpace
//    func test_propose_suggestion_overlap_pure_spaces() async throws {
//        let content = """
//        func quickSort() {
//            
//        }
//        """ // Yes the second line has 4 spaces!
//        let text = """
//            var array = [1, 3, 2, 4, 5, 6, 7, 8, 9, 10]
//            var left = 0
//            var right = array.count - 1
//            quickSort(&array, left, right)
//            print(array)
//        """
//        let suggestion = CodeSuggestion(
//            id: "",
//            text: text,
//            position: .init(line: 1, character: 0),
//            range: .init(
//                start: .init(line: 1, character: 0),
//                end: .init(line: 2, character: 18)
//            )
//        )
//        var extraInfo = SuggestionInjector.ExtraInfo()
//        var lines = content.breakLines()
//        SuggestionInjector().proposeSuggestion(
//            intoContentWithoutSuggestion: &lines,
//            completion: suggestion,
//            index: 0,
//            count: 10,
//            extraInfo: &extraInfo
//        )
//        XCTAssertTrue(extraInfo.didChangeContent)
//        XCTAssertFalse(extraInfo.didChangeCursorPosition)
//        XCTAssertEqual(extraInfo.suggestionRange, 2...8)
//        XCTAssertEqual(lines, content.breakLines().applying(extraInfo.modifications))
//        XCTAssertEqual(lines.joined(separator: ""), """
//        func quickSort() {
//            
//        /*========== Copilot Suggestion 1/10
//           ^var array = [1, 3, 2, 4, 5, 6, 7, 8, 9, 10]
//            var left = 0
//            var right = array.count - 1
//            quickSort(&array, left, right)
//            print(array)
//        *///======== End of Copilot Suggestion
//        }
//        """) // Yes the second line still has 4 spaces!
//    }
//
//    // swiftformat:enable all
//
//    func test_propose_suggestion_partial_overlap() async throws {
//        let content = "func quickSort() {}}\n"
//        let text = """
//        func quickSort() {
//            var array = [1, 3, 2, 4, 5, 6, 7, 8, 9, 10]
//            var left = 0
//            var right = array.count - 1
//            quickSort(&array, left, right)
//            print(array)
//        }
//        """
//        let suggestion = CodeSuggestion(
//            id: "",
//            text: text,
//            position: .init(line: 0, character: 0),
//            range: .init(
//                start: .init(line: 0, character: 0),
//                end: .init(line: 5, character: 15)
//            )
//        )
//        var extraInfo = SuggestionInjector.ExtraInfo()
//        var lines = content.breakLines()
//        SuggestionInjector().proposeSuggestion(
//            intoContentWithoutSuggestion: &lines,
//            completion: suggestion,
//            index: 0,
//            count: 10,
//            extraInfo: &extraInfo
//        )
//        XCTAssertTrue(extraInfo.didChangeContent)
//        XCTAssertFalse(extraInfo.didChangeCursorPosition)
//        XCTAssertEqual(extraInfo.suggestionRange, 1...9)
//        XCTAssertEqual(lines, content.breakLines().applying(extraInfo.modifications))
//        XCTAssertEqual(lines.joined(separator: ""), """
//        func quickSort() {}}
//        /*========== Copilot Suggestion 1/10
//                         ^
//            var array = [1, 3, 2, 4, 5, 6, 7, 8, 9, 10]
//            var left = 0
//            var right = array.count - 1
//            quickSort(&array, left, right)
//            print(array)
//        }
//        *///======== End of Copilot Suggestion
//
//        """)
//    }
//
//    func test_propose_suggestion_overlap_one_line_adding_only_spaces() async throws {
//        let content = """
//        if true {
//            print("hello")
//        } else {
//            print("world")
//        }
//        """
//        let text = "} else {\n"
//        let suggestion = CodeSuggestion(
//            id: "",
//            text: text,
//            position: .init(line: 2, character: 0),
//            range: .init(
//                start: .init(line: 2, character: 0),
//                end: .init(line: 2, character: 8)
//            )
//        )
//        var extraInfo = SuggestionInjector.ExtraInfo()
//        var lines = content.breakLines()
//        SuggestionInjector().proposeSuggestion(
//            intoContentWithoutSuggestion: &lines,
//            completion: suggestion,
//            index: 0,
//            count: 10,
//            extraInfo: &extraInfo
//        )
//        XCTAssertFalse(extraInfo.didChangeContent)
//        XCTAssertFalse(extraInfo.didChangeCursorPosition)
//        XCTAssertNil(extraInfo.suggestionRange)
//        XCTAssertEqual(lines, content.breakLines().applying(extraInfo.modifications))
//        XCTAssertEqual(lines.joined(separator: ""), """
//        if true {
//            print("hello")
//        } else {
//            print("world")
//        }
//        """)
//    }
//}
