//import SuggestionBasic
//import XCTest
//
//@testable import SuggestionInjector
//
//final class RejectSuggestionTests: XCTestCase {
//    func test_rejecting_suggestion() async throws {
//        let content = """
//        struct Cat {
//            var name
//        /*========== Copilot Suggestion 1/10
//                   ^: String
//            var age: String
//        *///======== End of Copilot Suggestion
//        }
//        """
//        var extraInfo = SuggestionInjector.ExtraInfo()
//        var lines = content.breakLines()
//        var cursor = CursorPosition(line: 1, character: 12)
//        SuggestionInjector().rejectCurrentSuggestions(
//            from: &lines,
//            cursorPosition: &cursor,
//            extraInfo: &extraInfo
//        )
//        XCTAssertTrue(extraInfo.didChangeContent)
//        XCTAssertFalse(extraInfo.didChangeCursorPosition)
//        XCTAssertNil(extraInfo.suggestionRange)
//        XCTAssertEqual(lines, content.breakLines().applying(extraInfo.modifications))
//        XCTAssertEqual(lines.joined(separator: ""), """
//        struct Cat {
//            var name
//        }
//        """)
//        XCTAssertEqual(
//            cursor,
//            .init(line: 1, character: 12),
//            "If cursor is above deletion, don't move it."
//        )
//    }
//
//    func test_broken_suggestion() async throws {
//        let content = """
//        struct Cat {
//            var name
//        /*========== Copilot Suggestion 1/10
//                   ^: String
//            var age: String
//        *///======== End of Copilot Suggestion
//
//        /*========== Copilot Suggestion 2/10
//
//        /*========== Copilot Suggestion 1/10
//                   ^: String
//            var age: String
//        *///======== End of Copilot Suggestion
//        """
//        var extraInfo = SuggestionInjector.ExtraInfo()
//        var lines = content.breakLines()
//        var cursor = CursorPosition(line: 6, character: 0)
//        SuggestionInjector().rejectCurrentSuggestions(
//            from: &lines,
//            cursorPosition: &cursor,
//            extraInfo: &extraInfo
//        )
//        XCTAssertTrue(extraInfo.didChangeContent)
//        XCTAssertTrue(extraInfo.didChangeCursorPosition)
//        XCTAssertNil(extraInfo.suggestionRange)
//        XCTAssertEqual(lines, content.breakLines().applying(extraInfo.modifications))
//        XCTAssertEqual(lines.joined(separator: ""), """
//        struct Cat {
//            var name
//
//        /*========== Copilot Suggestion 2/10
//
//
//        """)
//        XCTAssertEqual(
//            cursor,
//            .init(line: 2, character: 0),
//            "If cursor is below deletion, move it up."
//        )
//    }
//}
