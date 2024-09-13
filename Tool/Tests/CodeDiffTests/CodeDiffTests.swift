import Foundation
import XCTest

@testable import CodeDiff

class CodeDiffTests: XCTestCase {
    func test_diff_snippets_empty_snippets() {
        XCTAssertEqual(
            CodeDiff().diff(snippet: "", from: ""),
            .init(sections: [
                .init(oldSnippet: [.init(text: "")], newSnippet: [.init(text: "")]),
            ])
        )
    }

    func test_diff_snippets_from_empty_to_content() {
        XCTAssertEqual(
            CodeDiff().diff(
                snippet: """
                let foo = Foo()
                foo.bar()
                """,
                from: ""
            ),
            .init(sections: [
                .init(
                    oldSnippet: [.init(text: "", diff: .mutated(changes: []))],
                    newSnippet: [
                        .init(
                            text: "let foo = Foo()",
                            diff: .mutated(changes: [.init(
                                offset: 0,
                                element: "let foo = Foo()"
                            )])
                        ),
                        .init(
                            text: "foo.bar()",
                            diff: .mutated(changes: [.init(offset: 0, element: "foo.bar()")])
                        ),
                    ]
                ),
            ])
        )
    }

    func test_diff_snippets_from_content_to_empty() {
        XCTAssertEqual(
            CodeDiff().diff(
                snippet: "",
                from: """
                let foo = Foo()
                foo.bar()
                """
            ),
            .init(sections: [
                .init(
                    oldSnippet: [
                        .init(
                            text: "let foo = Foo()",
                            diff: .mutated(changes: [.init(
                                offset: 0,
                                element: "let foo = Foo()"
                            )])
                        ),
                        .init(
                            text: "foo.bar()",
                            diff: .mutated(changes: [.init(offset: 0, element: "foo.bar()")])
                        ),
                    ],
                    newSnippet: [.init(text: "", diff: .mutated(changes: []))]
                ),
            ])
        )
    }

    func test_diff_snippets_mutation() {
        XCTAssertEqual(
            CodeDiff().diff(
                snippet: """
                var foo = Bar()
                foo.baz()
                print(foo)
                """,
                from: """
                let foo = Foo()
                foo.bar()
                """
            ),
            .init(sections: [
                .init(
                    oldSnippet: [
                        .init(
                            text: "let foo = Foo()",
                            diff: .mutated(changes: [
                                .init(offset: 0, element: "let"),
                                .init(offset: 10, element: "Foo"),
                            ])
                        ),
                        .init(
                            text: "foo.bar()",
                            diff: .mutated(changes: [
                                .init(offset: 6, element: "r"),
                            ])
                        ),
                    ],
                    newSnippet: [
                        .init(
                            text: "var foo = Bar()",
                            diff: .mutated(changes: [
                                .init(offset: 0, element: "var"),
                                .init(offset: 10, element: "Bar"),
                            ])
                        ),
                        .init(
                            text: "foo.baz()",
                            diff: .mutated(changes: [
                                .init(offset: 6, element: "z"),
                            ])
                        ),
                        .init(
                            text: "print(foo)",
                            diff: .mutated(changes: [
                                .init(offset: 0, element: "print(foo)"),
                            ])
                        ),
                    ]
                ),
            ])
        )
    }

    func test_diff_snippets_multiple_sections() {
        XCTAssertEqual(
            CodeDiff().diff(
                snippet: """
                var foo = Bar()
                foo.baz()
                // divider a
                print(foo)
                // divider b
                // divider c
                func bar() {
                    print(foo)
                }
                """,
                from: """
                let foo = Foo()
                foo.bar()
                // divider a
                // divider b
                // divider c
                func bar() {}
                """
            ),
            .init(sections: [
                .init(
                    oldSnippet: [
                        .init(
                            text: "let foo = Foo()",
                            diff: .mutated(changes: [
                                .init(offset: 0, element: "let"),
                                .init(offset: 10, element: "Foo"),
                            ])
                        ),
                        .init(
                            text: "foo.bar()",
                            diff: .mutated(changes: [
                                .init(offset: 6, element: "r"),
                            ])
                        ),
                    ],
                    newSnippet: [
                        .init(
                            text: "var foo = Bar()",
                            diff: .mutated(changes: [
                                .init(offset: 0, element: "var"),
                                .init(offset: 10, element: "Bar"),
                            ])
                        ),
                        .init(
                            text: "foo.baz()",
                            diff: .mutated(changes: [
                                .init(offset: 6, element: "z"),
                            ])
                        ),
                    ]
                ),
                .init(
                    oldSnippet: [.init(text: "// divider a")],
                    newSnippet: [.init(text: "// divider a")]
                ),
                .init(
                    oldSnippet: [],
                    newSnippet: [
                        .init(
                            text: "print(foo)",
                            diff: .mutated(changes: [
                                .init(offset: 0, element: "print(foo)"),
                            ])
                        ),
                    ]
                ),
                .init(
                    oldSnippet: [.init(text: "// divider b"), .init(text: "// divider c")],
                    newSnippet: [.init(text: "// divider b"), .init(text: "// divider c")]
                ),
                .init(
                    oldSnippet: [
                        .init(
                            text: "func bar() {}",
                            diff: .mutated(changes: [
                                .init(offset: 12, element: "}"),
                            ])
                        ),
                    ],
                    newSnippet: [
                        .init(
                            text: "func bar() {",
                            diff: .mutated(changes: [])
                        ),
                        .init(
                            text: "    print(foo)",
                            diff: .mutated(changes: [.init(offset: 0, element: "    print(foo)")])
                        ),
                        .init(
                            text: "}",
                            diff: .mutated(changes: [.init(offset: 0, element: "}")])
                        ),
                    ]
                ),
            ])
        )
    }

    func test_diff_snippets_multiple_sections_beginning_unchanged() {
        XCTAssertEqual(
            CodeDiff().diff(
                snippet: """
                // unchanged
                // unchanged
                var foo = Bar()
                foo.baz()
                // divider a
                print(foo)
                """,
                from: """
                // unchanged
                // unchanged
                let foo = Foo()
                foo.bar()
                // divider a
                """
            ),
            .init(sections: [
                .init(
                    oldSnippet: [.init(text: "// unchanged"), .init(text: "// unchanged")],
                    newSnippet: [.init(text: "// unchanged"), .init(text: "// unchanged")]
                ),
                .init(
                    oldSnippet: [
                        .init(
                            text: "let foo = Foo()",
                            diff: .mutated(changes: [
                                .init(offset: 0, element: "let"),
                                .init(offset: 10, element: "Foo"),
                            ])
                        ),
                        .init(
                            text: "foo.bar()",
                            diff: .mutated(changes: [
                                .init(offset: 6, element: "r"),
                            ])
                        ),
                    ],
                    newSnippet: [
                        .init(
                            text: "var foo = Bar()",
                            diff: .mutated(changes: [
                                .init(offset: 0, element: "var"),
                                .init(offset: 10, element: "Bar"),
                            ])
                        ),
                        .init(
                            text: "foo.baz()",
                            diff: .mutated(changes: [
                                .init(offset: 6, element: "z"),
                            ])
                        ),
                    ]
                ),
                .init(
                    oldSnippet: [.init(text: "// divider a")],
                    newSnippet: [.init(text: "// divider a")]
                ),
                .init(
                    oldSnippet: [],
                    newSnippet: [
                        .init(
                            text: "print(foo)",
                            diff: .mutated(changes: [
                                .init(offset: 0, element: "print(foo)"),
                            ])
                        ),
                    ]
                ),
            ])
        )
    }

    func test_diff_snippets_multiple_sections_beginning_unchanged_reversed() {
        XCTAssertEqual(
            CodeDiff().diff(
                snippet: """
                // unchanged
                // unchanged
                let foo = Foo()
                foo.bar()
                // divider a
                """,
                from: """
                // unchanged
                // unchanged
                var foo = Bar()
                foo.baz()
                // divider a
                print(foo)
                """
            ),
            .init(sections: [
                .init(
                    oldSnippet: [.init(text: "// unchanged"), .init(text: "// unchanged")],
                    newSnippet: [.init(text: "// unchanged"), .init(text: "// unchanged")]
                ),
                .init(
                    oldSnippet: [
                        .init(
                            text: "var foo = Bar()",
                            diff: .mutated(changes: [
                                .init(offset: 0, element: "var"),
                                .init(offset: 10, element: "Bar"),
                            ])
                        ),
                        .init(
                            text: "foo.baz()",
                            diff: .mutated(changes: [
                                .init(offset: 6, element: "z"),
                            ])
                        ),
                    ],
                    newSnippet: [
                        .init(
                            text: "let foo = Foo()",
                            diff: .mutated(changes: [
                                .init(offset: 0, element: "let"),
                                .init(offset: 10, element: "Foo"),
                            ])
                        ),
                        .init(
                            text: "foo.bar()",
                            diff: .mutated(changes: [
                                .init(offset: 6, element: "r"),
                            ])
                        ),
                    ]
                ),
                .init(
                    oldSnippet: [.init(text: "// divider a")],
                    newSnippet: [.init(text: "// divider a")]
                ),
                .init(
                    oldSnippet: [.init(
                        text: "print(foo)",
                        diff: .mutated(changes: [
                            .init(offset: 0, element: "print(foo)"),
                        ])
                    )],
                    newSnippet: []
                ),
            ])
        )
    }

    func test_diff_snippets_multiple_sections_more_unbalanced_sections_reversed() {
        XCTAssertEqual(
            CodeDiff().diff(
                snippet: """
                let foo = Foo()
                foo.bar()
                // divider a
                // divider b
                // divider c
                func bar() {}
                """,
                from: """
                var foo = Bar()
                foo.baz()
                // divider a
                print(foo)
                // divider b
                print(foo)
                // divider c
                func bar() {
                    print(foo)
                }
                """
            ),
            .init(sections: [
                .init(
                    oldSnippet: [
                        .init(
                            text: "var foo = Bar()",
                            diff: .mutated(changes: [
                                .init(offset: 0, element: "var"),
                                .init(offset: 10, element: "Bar"),
                            ])
                        ),
                        .init(
                            text: "foo.baz()",
                            diff: .mutated(changes: [
                                .init(offset: 6, element: "z"),
                            ])
                        ),
                    ],
                    newSnippet: [
                        .init(
                            text: "let foo = Foo()",
                            diff: .mutated(changes: [
                                .init(offset: 0, element: "let"),
                                .init(offset: 10, element: "Foo"),
                            ])
                        ),
                        .init(
                            text: "foo.bar()",
                            diff: .mutated(changes: [
                                .init(offset: 6, element: "r"),
                            ])
                        ),
                    ]
                ),
                .init(
                    oldSnippet: [.init(text: "// divider a")],
                    newSnippet: [.init(text: "// divider a")]
                ),
                .init(
                    oldSnippet: [.init(
                        text: "print(foo)",
                        diff: .mutated(changes: [
                            .init(offset: 0, element: "print(foo)"),
                        ])
                    ),],
                    newSnippet: []
                ),
                .init(
                    oldSnippet: [.init(text: "// divider b")],
                    newSnippet: [.init(text: "// divider b")]
                ),
                .init(
                    oldSnippet: [.init(
                        text: "print(foo)",
                        diff: .mutated(changes: [
                            .init(offset: 0, element: "print(foo)"),
                        ])
                    )],
                    newSnippet: []
                ),
                .init(
                    oldSnippet: [.init(text: "// divider c")],
                    newSnippet: [.init(text: "// divider c")]
                ),
                .init(
                    oldSnippet: [
                        .init(
                            text: "func bar() {",
                            diff: .mutated(changes: [])
                        ),
                        .init(
                            text: "    print(foo)",
                            diff: .mutated(changes: [.init(offset: 0, element: "    print(foo)")])
                        ),
                        .init(
                            text: "}",
                            diff: .mutated(changes: [.init(offset: 0, element: "}")])
                        ),
                    ],
                    newSnippet: [
                        .init(
                            text: "func bar() {}",
                            diff: .mutated(changes: [
                                .init(offset: 12, element: "}"),
                            ])
                        ),
                    ]
                ),
            ])
        )
    }
}

