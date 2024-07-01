import Foundation
import SuggestionBasic
import XCTest

@testable import FocusedCodeFinder

class UnknownLanguageFocusedCodeFinderTests: XCTestCase {
    func test_the_code_is_long_enough_for_the_search_range() {
        let code = stride(from: 0, through: 100, by: 1).map { "\($0)\n" }.joined()
        let context = UnknownLanguageFocusedCodeFinder(proposedSearchRange: 5)
            .findFocusedCode(
                in: document(code: code),
                containingRange: .init(startPair: (50, 0), endPair: (50, 0))
            )
        XCTAssertEqual(context, .init(
            scope: .top,
            contextRange: .init(startPair: (40, 0), endPair: (60, 3)),
            smallestContextRange: .init(startPair: (40, 0), endPair: (60, 3)),
            focusedRange: .init(startPair: (45, 0), endPair: (55, 3)),
            focusedCode: stride(from: 45, through: 55, by: 1).map { "\($0)\n" }.joined(),
            imports: [],
            includes: []
        ))
    }

    func test_the_upper_side_is_not_long_enough_expand_the_lower_end() {
        let code = stride(from: 0, through: 100, by: 1).map { "\($0)\n" }.joined()
        let context = UnknownLanguageFocusedCodeFinder(proposedSearchRange: 5)
            .findFocusedCode(
                in: document(code: code),
                containingRange: .init(startPair: (2, 0), endPair: (2, 0))
            )
        XCTAssertEqual(context, .init(
            scope: .top,
            contextRange: .init(startPair: (0, 0), endPair: (15, 3)),
            smallestContextRange: .init(startPair: (0, 0), endPair: (15, 3)),
            focusedRange: .init(startPair: (0, 0), endPair: (10, 3)),
            focusedCode: stride(from: 0, through: 10, by: 1).map { "\($0)\n" }.joined(),
            imports: [],
            includes: []
        ))
    }

    func test_the_lower_side_is_not_long_enough_do_not_expand_the_upper_end() {
        let code = stride(from: 0, through: 100, by: 1).map { "\($0)\n" }.joined()
        let context = UnknownLanguageFocusedCodeFinder(proposedSearchRange: 5)
            .findFocusedCode(
                in: document(code: code),
                containingRange: .init(startPair: (99, 0), endPair: (99, 0))
            )
        XCTAssertEqual(context, .init(
            scope: .top,
            contextRange: .init(startPair: (89, 0), endPair: (101, 1)),
            smallestContextRange: .init(startPair: (89, 0), endPair: (101, 1)),
            focusedRange: .init(startPair: (94, 0), endPair: (101, 1)),
            focusedCode: stride(from: 94, through: 100, by: 1).map { "\($0)\n" }.joined() + "\n",
            imports: [],
            includes: []
        ))
    }

    func test_both_sides_are_just_long_enough() {
        let code = stride(from: 0, through: 10, by: 1).map { "\($0)\n" }.joined()
        let context = UnknownLanguageFocusedCodeFinder(proposedSearchRange: 5)
            .findFocusedCode(
                in: document(code: code),
                containingRange: .init(startPair: (5, 0), endPair: (5, 0))
            )
        XCTAssertEqual(context, .init(
            scope: .top,
            contextRange: .init(startPair: (0, 0), endPair: (11, 1)),
            smallestContextRange: .init(startPair: (0, 0), endPair: (11, 1)),
            focusedRange: .init(startPair: (0, 0), endPair: (10, 3)),
            focusedCode: code,
            imports: [],
            includes: []
        ))
    }

    func test_both_sides_are_not_long_enough() {
        let code = stride(from: 0, through: 4, by: 1).map { "\($0)\n" }.joined()
        let context = UnknownLanguageFocusedCodeFinder(proposedSearchRange: 5)
            .findFocusedCode(
                in: document(code: code),
                containingRange: .init(startPair: (3, 0), endPair: (3, 0))
            )
        XCTAssertEqual(context, .init(
            scope: .top,
            contextRange: .init(startPair: (0, 0), endPair: (5, 1)),
            smallestContextRange: .init(startPair: (0, 0), endPair: (5, 1)),
            focusedRange: .init(startPair: (0, 0), endPair: (5, 1)),
            focusedCode: code + "\n",
            imports: [],
            includes: []
        ))
    }
}

