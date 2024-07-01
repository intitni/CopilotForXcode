import Foundation
import SuggestionBasic
import XCTest

@testable import XcodeInspector

class SourceEditorRangeConversionTests: XCTestCase {
    // MARK: - Convert to CursorRange

    func test_convert_multiline_range() {
        let code = """
        import Foundation
        import XCTest

        class SourceEditorRangeConversionTests {
            func testSomething() {
                // test
            }
        }

        """

        let range = 21...39
        let cursorRange = SourceEditor.convertRangeToCursorRange(range, in: code)

        XCTAssertEqual(cursorRange.start, .init(line: 1, character: 3))
        XCTAssertEqual(cursorRange.end, .init(line: 3, character: 6))
    }

    func test_convert_multiline_range_with_special_line_endings() {
        let code = """
        import Foundation
        import XCTest

        class SourceEditorRangeConversionTests {
            func testSomething() {
                // test
            }
        }

        """.replacingOccurrences(of: "\n", with: "\r\n")

        let range = 21...39
        let cursorRange = SourceEditor.convertRangeToCursorRange(range, in: code)

        XCTAssertEqual(cursorRange.start, .init(line: 1, character: 2))
        XCTAssertEqual(cursorRange.end, .init(line: 3, character: 3))
    }

    func test_convert_multiline_range_with_emoji() {
        let code = """
        import Foundation
        import 🎆🎆🎆🎆🎆🎆

        class SourceEditorRangeConversionTests {
            func testSomething() {
                // test
            }
        }

        """

        let range = 21...42
        let cursorRange = SourceEditor.convertRangeToCursorRange(range, in: code)

        XCTAssertEqual(cursorRange.start, .init(line: 1, character: 3))
        XCTAssertEqual(cursorRange.end, .init(line: 3, character: 3))
    }
    
    func test_convert_multiline_range_cutting_emoji() {
        // undefined behavior
        
        let code = """
        import Foundation
        import 🎆🎆🎆🎆🎆🎆

        class SourceEditorRangeConversionTests {
            func testSomething() {
                // test
            }
        }

        """

        let range = 26...42 // in the middle of the emoji
        let cursorRange = SourceEditor.convertRangeToCursorRange(range, in: code)

        XCTAssertEqual(cursorRange.start, .init(line: 1, character: 8))
        XCTAssertEqual(cursorRange.end, .init(line: 3, character: 3))
    }

    func test_convert_range_with_no_code() {
        let code = ""
        let range = 21...39
        let cursorRange = SourceEditor.convertRangeToCursorRange(range, in: code)

        XCTAssertEqual(cursorRange.start, .zero)
        XCTAssertEqual(cursorRange.end, .zero)
    }

    func test_convert_multiline_range_with_out_of_range_cursor() {
        let code = """
        import Foundation
        import XCTest

        class SourceEditorRangeConversionTests {
            func testSomething() {
                // test
            }
        }

        """

        let range = 999...1000
        let cursorRange = SourceEditor.convertRangeToCursorRange(range, in: code)

        // undefined behavior

        XCTAssertEqual(cursorRange.start, .zero)
        XCTAssertEqual(cursorRange.end, .init(line: 8, character: 0))
    }

    // MARK: - Convert to CFRange

    func test_back_convert_multiline_cursor_range() {
        let code = """
        import Foundation
        import XCTest

        class SourceEditorRangeConversionTests {
            func testSomething() {
                // test
            }
        }

        """

        let cursorRange = CursorRange(
            start: .init(line: 1, character: 3),
            end: .init(line: 3, character: 6)
        )
        let range = SourceEditor.convertCursorRangeToRange(cursorRange, in: code)

        XCTAssertEqual(range.range, 21...39)
    }

    func test_back_convert_multiline_range_with_out_of_range_cursor() {
        let code = """
        import Foundation
        import XCTest

        class SourceEditorRangeConversionTests {
            func testSomething() {
                // test
            }
        }

        """

        let cursorRange = CursorRange(
            start: .init(line: 999, character: 0),
            end: .init(line: 1000, character: 0)
        )
        let range = SourceEditor.convertCursorRangeToRange(cursorRange, in: code)

        // undefined behavior

        XCTAssertEqual(range.range, 0...0)
    }

    func test_back_convert_multiline_range_with_special_line_endings() {
        let code = """
        import Foundation
        import XCTest

        class SourceEditorRangeConversionTests {
            func testSomething() {
                // test
            }
        }

        """.replacingOccurrences(of: "\n", with: "\r\n")

        let cursorRange = CursorRange(
            start: .init(line: 1, character: 2),
            end: .init(line: 3, character: 3)
        )
        let range = SourceEditor.convertCursorRangeToRange(cursorRange, in: code)

        XCTAssertEqual(range.range, 21...39)
    }

    func test_back_convert_multiline_range_with_emoji() {
        let code = """
        import Foundation
        import 🎆🎆🎆🎆🎆🎆

        class SourceEditorRangeConversionTests {
            func testSomething() {
                // test
            }
        }

        """

        let cursorRange = CursorRange(
            start: .init(line: 1, character: 3),
            end: .init(line: 3, character: 3)
        )
        let range = SourceEditor.convertCursorRangeToRange(cursorRange, in: code)
        XCTAssertEqual(range.range, 21...42)
    }

    func test_back_convert_range_with_no_code() {
        let code = ""
        let range = 21...39
        let cursorRange = SourceEditor.convertCursorRangeToRange(
            SourceEditor.convertRangeToCursorRange(range, in: code),
            in: code
        )

        XCTAssertEqual(cursorRange.range, 0...0)
    }
}

private extension CFRange {
    var range: ClosedRange<Int> {
        return location...(location + length)
    }
}

