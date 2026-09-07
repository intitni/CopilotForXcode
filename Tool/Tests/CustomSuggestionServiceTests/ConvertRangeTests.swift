import CopilotForXcodeKit
import XCTest

@testable import CustomSuggestionService

class ConvertRangeTests: XCTestCase {
    func test_convert_range_0_0() {
        XCTAssertEqual(
            convertRangeToCursorRange(0...0, in: "\n".breakLines()),
            CursorRange(start: .zero, end: .init(line: 0, character: 0))
        )
    }

    func test_convert_range_same_line() {
        XCTAssertEqual(
            convertRangeToCursorRange(1...5, in: "123456789\n".breakLines()),
            CursorRange(start: .init(line: 0, character: 1), end: .init(line: 0, character: 5))
        )
    }

    func test_convert_range_multiple_line() {
        XCTAssertEqual(
            convertRangeToCursorRange(5...25, in: "123456789\n123456789\n123456789\n".breakLines()),
            CursorRange(start: .init(line: 0, character: 5), end: .init(line: 2, character: 5))
        )
    }

    func test_convert_range_all_line() {
        XCTAssertEqual(
            convertRangeToCursorRange(0...29, in: "123456789\n123456789\n123456789\n".breakLines()),
            CursorRange(start: .init(line: 0, character: 0), end: .init(line: 2, character: 9))
        )
    }

    func test_convert_range_out_of_range() {
        XCTAssertEqual(
            convertRangeToCursorRange(0...70, in: "123456789\n123456789\n123456789\n".breakLines()),
            CursorRange(start: .init(line: 0, character: 0), end: .init(line: 3, character: 0))
        )
    }
}

