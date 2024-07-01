import Foundation
import SuggestionBasic
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
        let context = ObjectiveCFocusedCodeFinder(maxFocusedCodeLineCount: .max).findFocusedCode(
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
            smallestContextRange: range,
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
        let context = ObjectiveCFocusedCodeFinder(maxFocusedCodeLineCount: .max).findFocusedCode(
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
            smallestContextRange: range,
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
        __attribute__((objc_nonlazy_class))
        @implementation Foo (Category)
        - (void)fooWith:(NSInteger)foo {
            NSInteger foo = 0;
            NSLog(@"Hello");
            NSLog(@"World");
        }
        @end
        """
        let range = CursorRange(
            start: CursorPosition(line: 2, character: 0),
            end: CursorPosition(line: 6, character: 1)
        )
        let context = ObjectiveCFocusedCodeFinder(maxFocusedCodeLineCount: .max).findFocusedCode(
            in: document(code: code),
            containingRange: range
        )
        XCTAssertEqual(context, .init(
            scope: .scope(signature: [
                .init(
                    signature: "__attribute__((objc_nonlazy_class)) @implementation Foo (Category)",
                    name: "Foo",
                    range: .init(startPair: (0, 0), endPair: (7, 4))
                ),
            ]),
            contextRange: .init(startPair: (0, 0), endPair: (7, 4)),
            smallestContextRange: range,
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
        @interface ViewController <ObjectType: id<UITableViewDelegate, UITableViewDataSource>>: NSObject <ProtocolName>
        - (void)fooWith:(NSInteger)foo;
        - (void)fooWith:(NSInteger)foo;
        - (void)fooWith:(NSInteger)foo;
        @end
        """
        let range = CursorRange(
            start: CursorPosition(line: 1, character: 0),
            end: CursorPosition(line: 3, character: 31)
        )
        let context = ObjectiveCFocusedCodeFinder(maxFocusedCodeLineCount: .max).findFocusedCode(
            in: document(code: code),
            containingRange: range
        )
        XCTAssertEqual(context, .init(
            scope: .scope(signature: [
                .init(
                    signature: "@interface ViewController<ObjectType: id<UITableViewDelegate, UITableViewDataSource>>: NSObject<ProtocolName>",
                    name: "ViewController",
                    range: .init(startPair: (0, 0), endPair: (4, 4))
                ),
            ]),
            contextRange: .init(startPair: (0, 0), endPair: (4, 4)),
            smallestContextRange: range,
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

    func test_selecting_a_line_inside_an_interface_category_the_scope_should_be_the_interface() {
        let code = """
        @interface __GENERICS(NSArray, ObjectType) (BlocksKit)
        - (void)fooWith:(NSInteger)foo;
        - (void)fooWith:(NSInteger)foo;
        - (void)fooWith:(NSInteger)foo;
        @end
        """
        let range = CursorRange(
            start: CursorPosition(line: 1, character: 0),
            end: CursorPosition(line: 3, character: 31)
        )
        let context = ObjectiveCFocusedCodeFinder(maxFocusedCodeLineCount: .max).findFocusedCode(
            in: document(code: code),
            containingRange: range
        )
        XCTAssertEqual(context, .init(
            scope: .scope(signature: [
                .init(
                    signature: "@interface __GENERICS(NSArray, ObjectType) (BlocksKit)",
                    name: "NSArray",
                    range: .init(startPair: (0, 0), endPair: (4, 4))
                ),
            ]),
            contextRange: .init(startPair: (0, 0), endPair: (4, 4)),
            smallestContextRange: range,
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

    func test_selecting_a_line_inside_a_protocol_the_scope_should_be_the_protocol() {
        let code = """
        @protocol Foo<A, B>
        - (void)fooWith:(NSInteger)foo;
        - (void)fooWith:(NSInteger)foo;
        - (void)fooWith:(NSInteger)foo;
        @end
        """
        let range = CursorRange(
            start: CursorPosition(line: 1, character: 0),
            end: CursorPosition(line: 3, character: 31)
        )
        let context = ObjectiveCFocusedCodeFinder(maxFocusedCodeLineCount: .max).findFocusedCode(
            in: document(code: code),
            containingRange: range
        )
        XCTAssertEqual(context, .init(
            scope: .scope(signature: [
                .init(
                    signature: "@protocol Foo<A, B>",
                    name: "Foo",
                    range: .init(startPair: (0, 0), endPair: (4, 4))
                ),
            ]),
            contextRange: .init(startPair: (0, 0), endPair: (4, 4)),
            smallestContextRange: range,
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

    func test_selecting_a_line_inside_a_struct_the_scope_should_be_the_struct() {
        let code = """
        struct Foo {
            NSInteger foo;
            NSInteger bar;
            NSInteger baz;
        }
        """
        let range = CursorRange(
            start: CursorPosition(line: 1, character: 0),
            end: CursorPosition(line: 3, character: 31)
        )
        let context = ObjectiveCFocusedCodeFinder(maxFocusedCodeLineCount: .max).findFocusedCode(
            in: document(code: code),
            containingRange: range
        )
        XCTAssertEqual(context, .init(
            scope: .scope(signature: [
                .init(
                    signature: "struct Foo",
                    name: "Foo",
                    range: .init(startPair: (0, 0), endPair: (4, 1))
                ),
            ]),
            contextRange: .init(startPair: (0, 0), endPair: (4, 1)),
            smallestContextRange: range,
            focusedRange: range,
            focusedCode: """
                NSInteger foo;
                NSInteger bar;
                NSInteger baz;

            """,
            imports: [],
            includes: []
        ))
    }

    func test_selecting_a_line_inside_a_enum_the_scope_should_be_the_enum() {
        let code = """
        enum Foo {
            foo,
            bar,
            baz
        };
        """
        let range = CursorRange(
            start: CursorPosition(line: 1, character: 0),
            end: CursorPosition(line: 3, character: 31)
        )
        let context = ObjectiveCFocusedCodeFinder(maxFocusedCodeLineCount: .max).findFocusedCode(
            in: document(code: code),
            containingRange: range
        )
        XCTAssertEqual(context, .init(
            scope: .scope(signature: [
                .init(
                    signature: "enum Foo",
                    name: "Foo",
                    range: .init(startPair: (0, 0), endPair: (4, 1))
                ),
            ]),
            contextRange: .init(startPair: (0, 0), endPair: (4, 1)),
            smallestContextRange: range,
            focusedRange: range,
            focusedCode: """
                foo,
                bar,
                baz

            """,
            imports: [],
            includes: []
        ))
    }

    func test_selecting_a_line_inside_an_NSEnum_the_scope_should_be_the_enum() {
        let code = """
        typedef NS_ENUM(NSInteger, Foo) {
            foo,
            bar,
            baz
        };
        """
        let range = CursorRange(
            start: CursorPosition(line: 1, character: 0),
            end: CursorPosition(line: 3, character: 31)
        )
        let context = ObjectiveCFocusedCodeFinder(maxFocusedCodeLineCount: .max).findFocusedCode(
            in: document(code: code),
            containingRange: range
        )
        XCTAssertEqual(context, .init(
            scope: .scope(signature: [
                .init(
                    signature: "typedef NS_ENUM(NSInteger, Foo)",
                    name: "Foo",
                    range: .init(startPair: (0, 0), endPair: (4, 2))
                ),
            ]),
            contextRange: .init(startPair: (0, 0), endPair: (4, 2)),
            smallestContextRange: range,
            focusedRange: range,
            focusedCode: """
                foo,
                bar,
                baz

            """,
            imports: [],
            includes: []
        ))
    }
}

final class ObjectiveCFocusedCodeFinder_Focus_Tests: XCTestCase {
    func test_get_focused_code_inside_method_the_method_should_be_the_focused_code() {
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
            end: CursorPosition(line: 2, character: 0)
        )
        let context = ObjectiveCFocusedCodeFinder(maxFocusedCodeLineCount: .max).findFocusedCode(
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
            ]),
            contextRange: .init(startPair: (0, 0), endPair: (6, 4)),
            smallestContextRange: .init(startPair: (1, 0), endPair: (5, 1)),
            focusedRange: .init(startPair: (1, 0), endPair: (5, 1)),
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

    func test_get_focused_code_inside_an_interface_category_the_focused_code_should_be_the_interface(
    ) {
        let code = """
        @interface __GENERICS(NSArray, ObjectType) (BlocksKit)
        - (void)fooWith:(NSInteger)foo;
        - (void)fooWith:(NSInteger)foo;
        - (void)fooWith:(NSInteger)foo;
        @end

        @implementation Foo
        @end
        """
        let range = CursorRange(
            start: CursorPosition(line: 1, character: 0),
            end: CursorPosition(line: 1, character: 0)
        )
        let context = ObjectiveCFocusedCodeFinder(maxFocusedCodeLineCount: .max).findFocusedCode(
            in: document(code: code),
            containingRange: range
        )
        XCTAssertEqual(context, .init(
            scope: .file,
            contextRange: .init(startPair: (0, 0), endPair: (0, 0)),
            smallestContextRange: .init(startPair: (0, 0), endPair: (4, 4)),
            focusedRange: .init(startPair: (0, 0), endPair: (4, 4)),
            focusedCode: """
            @interface __GENERICS(NSArray, ObjectType) (BlocksKit)
            - (void)fooWith:(NSInteger)foo;
            - (void)fooWith:(NSInteger)foo;
            - (void)fooWith:(NSInteger)foo;
            @end

            """,
            imports: [],
            includes: []
        ))
    }
}

final class ObjectiveCFocusedCodeFinder_Imports_Tests: XCTestCase {
    func test_parsing_imports() {
        let code = """
        #import <Foundation/Foundation.h>
        @import UIKit;
        #import "Foo.h"
        #include "Bar.h"
        """

        let context = ObjectiveCFocusedCodeFinder(maxFocusedCodeLineCount: .max).findFocusedCode(
            in: document(code: code),
            containingRange: .zero
        )

        XCTAssertEqual(context.imports, [
            "<Foundation/Foundation.h>",
            "UIKit",
            "\"Foo.h\"",
        ])
        XCTAssertEqual(context.includes, [
            "\"Bar.h\"",
        ])
    }
}

