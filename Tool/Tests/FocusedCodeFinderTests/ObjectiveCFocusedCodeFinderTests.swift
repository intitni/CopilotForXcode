import Foundation
import SuggestionModel
import XCTest

@testable import FocusedCodeFinder

final class ObjectiveCFocusedCodeFinder_Selection_Tests: XCTestCase {
    func test_selecting_a_line_inside_the_method_the_scope_should_be_the_method() {
        let code = """
        @implementation Foo
        - (void)fooWith:(NSInteger)foo {
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
                    signature: "- (void)fooWith:(NSInteger)foo",
                    name: "fooWith:(NSInteger)foo",
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
        void foo(char name[]) {
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
                    signature: "void foo(char name[])",
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
    
    func test_selecting_a_method_inside_an_implementation_the_scope_should_be_the_implementation() {
        let code = """
        @implementation Foo (Category)
        - (void)fooWith:(NSInteger)foo {
            NSInteger foo = 0;
            NSLog(@"Hello");
            NSLog(@"World");
        }
        @end
        """
        let range = CursorRange(
            start: CursorPosition(line: 1, character: 0),
            end: CursorPosition(line: 5, character: 1)
        )
        let context = ObjectiveCFocusedCodeFinder().findFocusedCode(
            in: document(code: code),
            containingRange: range
        )
        XCTAssertEqual(context, .init(
            scope: .scope(signature: [
                .init(
                    signature: "@implementation Foo (Category)",
                    name: "Foo",
                    range: .init(startPair: (0, 0), endPair: (6, 4))
                ),
            ]),
            contextRange: .init(startPair: (0, 0), endPair: (6, 4)),
            focusedRange: range,
            focusedCode: """
            - (void)fooWith:(NSInteger)foo {
                NSInteger foo = 0;
                NSLog(@"Hello");
                NSLog(@"World");
            }
            
            """,
            imports: [],
            includes: []
        ))
    }
    
    func test_selecting_a_line_inside_an_interface_the_scope_should_be_the_interface() {
        let code = """
        @interface Foo<A, B>: NSObject
        - (void)fooWith:(NSInteger)foo;
        - (void)fooWith:(NSInteger)foo;
        - (void)fooWith:(NSInteger)foo;
        @end
        """
        let range = CursorRange(
            start: CursorPosition(line: 1, character: 0),
            end: CursorPosition(line: 3, character: 31)
        )
        let context = ObjectiveCFocusedCodeFinder().findFocusedCode(
            in: document(code: code),
            containingRange: range
        )
        XCTAssertEqual(context, .init(
            scope: .scope(signature: [
                .init(
                    signature: "@interface Foo<A, B>: NSObject",
                    name: "Foo",
                    range: .init(startPair: (0, 0), endPair: (4, 4))
                ),
            ]),
            contextRange: .init(startPair: (0, 0), endPair: (4, 4)),
            focusedRange: range,
            focusedCode: """
            - (void)fooWith:(NSInteger)foo;
            - (void)fooWith:(NSInteger)foo;
            - (void)fooWith:(NSInteger)foo;
            
            """,
            imports: [],
            includes: []
        ))
    }
}

