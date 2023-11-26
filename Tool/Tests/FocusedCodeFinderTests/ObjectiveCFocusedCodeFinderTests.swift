import Foundation
import SuggestionModel
import XCTest

@testable import FocusedCodeFinder

final class ObjectiveCFocusedCodeFinder_Selection_Tests: XCTestCase {
    func test_selecting_a_line_inside_the_method_the_scope_should_be_the_method() {
        let code = """
        @implementation Foo
        - (void)foo {
            NSInteger foo = 0;
            NSLog(@"Hello");
            NSLog(@"World");
        }
        @end
        """
        let range = CursorRange(
            start: CursorPosition(line: 2, character: 0),
            end: CursorPosition(line: 2, character: 4)
        )
        let context = ObjectiveCFocusedCodeFinder().findFocusedCode(
            in: document(code: code),
            containingRange: range
        )
        XCTAssertEqual(context, .init(
            scope: .scope(signature: [
                .init(
                    signature: "@implementation Foo",
                    name: "Foo",
                    range: .init(startPair: (0, 0), endPair: (6, 4))
                ),
                .init(
                    signature: "- (void)foo",
                    name: "foo",
                    range: .init(startPair: (1, 0), endPair: (5, 1))
                ),
            ]),
            contextRange: .init(startPair: (0, 0), endPair: (6, 4)),
            focusedRange: range,
            focusedCode: """
                NSInteger foo = 0;

            """,
            imports: [],
            includes: []
        ))
    }

    func test_selecting_a_line_inside_a_function_the_scope_should_be_the_function() {
        let code = """
        void foo() {
            NSInteger foo = 0;
            NSLog(@"Hello");
            NSLog(@"World");
        }
        """
        let range = CursorRange(startPair: (2, 0), endPair: (2, 4))
        let context = ObjectiveCFocusedCodeFinder().findFocusedCode(
            in: document(code: code),
            containingRange: range
        )
        XCTAssertEqual(context, .init(
            scope: .scope(signature: [
                .init(
                    signature: "void foo()",
                    name: "foo",
                    range: .init(startPair: (0, 0), endPair: (4, 1))
                ),
            ]),
            contextRange: .init(startPair: (0, 0), endPair: (4, 1)),
            focusedRange: range,
            focusedCode: """
                NSLog(@"Hello");

            """,
            imports: [],
            includes: []
        ))
    }
}

