import Foundation
import XCTest

@testable import CodeDiff

class CodeDiffTests: XCTestCase {
    func test_diff_snippets_empty_snippets() {
        XCTAssertEqual(
            CodeDiff().diff(snippet: "", from: ""),
            .init(sections: [
                .init(
                    oldOffset: 0,
                    newOffset: 0,
                    oldSnippet: [.init(text: "")],
                    newSnippet: [.init(text: "")]
                ),
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
                    oldOffset: 0,
                    newOffset: 0,
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

    func test_diff_snippets_insert_at_top() {
        XCTAssertEqual(
            CodeDiff().diff(
                snippet: """
                let foo = Foo()
                foo.bar()
                """,
                from: """
                foo.bar()
                """
            ),
            .init(sections: [
                .init(
                    oldOffset: 0,
                    newOffset: 0,
                    oldSnippet: [],
                    newSnippet: [.init(
                        text: "let foo = Foo()",
                        diff: .mutated(changes: [CodeDiff.SnippetDiff.Change(
                            offset: 0,
                            element: "let foo = Foo()"
                        )])
                    )]
                ),

                .init(
                    oldOffset: 0,
                    newOffset: 1,
                    oldSnippet: [.init(text: "foo.bar()", diff: .unchanged)],
                    newSnippet: [.init(text: "foo.bar()", diff: .unchanged)]
                ),
            ])
        )
    }

    func test_diff_snippets_from_one_line_to_content() {
        XCTAssertEqual(
            CodeDiff().diff(
                snippet: """
                let foo = Foo()
                foo.bar()
                """,
                from: """
                // comment
                """
            ),
            .init(sections: [
                .init(
                    oldOffset: 0,
                    newOffset: 0,
                    oldSnippet: [.init(text: "// comment", diff: .mutated(changes: [
                        .init(offset: 0, element: "// comm"),
                        .init(offset: 8, element: "n"),
                    ]))],
                    newSnippet: [
                        .init(
                            text: "let foo = Foo()",
                            diff: .mutated(changes: [
                                .init(offset: 0, element: "l"),
                                .init(offset: 3, element: " foo = Foo()"),
                            ])
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
                    oldOffset: 0,
                    newOffset: 0,
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

    func test_diff_snippets_from_content_to_one_line() {
        XCTAssertEqual(
            CodeDiff().diff(
                snippet: """
                // comment
                    let foo = Bar()
                    print(bar)
                    print(foo)
                """,
                from: """
                    let foo = Bar()
                """
            ),
            .init(sections: [
                .init(
                    oldOffset: 0,
                    newOffset: 0,
                    oldSnippet: [],
                    newSnippet: [
                        .init(
                            text: "// comment",
                            diff: .mutated(changes: [.init(offset: 0, element: "// comment")])
                        ),
                    ]
                ),
                .init(
                    oldOffset: 0,
                    newOffset: 1,
                    oldSnippet: [
                        .init(text: "    let foo = Bar()"),
                    ],
                    newSnippet: [
                        .init(text: "    let foo = Bar()"),
                    ]
                ),
                .init(oldOffset: 1, newOffset: 2, oldSnippet: [], newSnippet: [
                    .init(
                        text: "    print(bar)",
                        diff: .mutated(changes: [.init(offset: 0, element: "    print(bar)")])
                    ),
                    .init(
                        text: "    print(foo)",
                        diff: .mutated(changes: [.init(offset: 0, element: "    print(foo)")])
                    ),
                ]),
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
                    oldOffset: 0,
                    newOffset: 0,
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
                    oldOffset: 0,
                    newOffset: 0,
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
                    oldOffset: 2,
                    newOffset: 2,
                    oldSnippet: [.init(text: "// divider a")],
                    newSnippet: [.init(text: "// divider a")]
                ),
                .init(
                    oldOffset: 3,
                    newOffset: 3,
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
                    oldOffset: 3,
                    newOffset: 4,
                    oldSnippet: [.init(text: "// divider b"), .init(text: "// divider c")],
                    newSnippet: [.init(text: "// divider b"), .init(text: "// divider c")]
                ),
                .init(
                    oldOffset: 5,
                    newOffset: 6,
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
                    oldOffset: 0,
                    newOffset: 0,
                    oldSnippet: [.init(text: "// unchanged"), .init(text: "// unchanged")],
                    newSnippet: [.init(text: "// unchanged"), .init(text: "// unchanged")]
                ),
                .init(
                    oldOffset: 2,
                    newOffset: 2,
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
                    oldOffset: 4,
                    newOffset: 4,
                    oldSnippet: [.init(text: "// divider a")],
                    newSnippet: [.init(text: "// divider a")]
                ),
                .init(
                    oldOffset: 5,
                    newOffset: 5,
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
                    oldOffset: 0,
                    newOffset: 0,
                    oldSnippet: [.init(text: "// unchanged"), .init(text: "// unchanged")],
                    newSnippet: [.init(text: "// unchanged"), .init(text: "// unchanged")]
                ),
                .init(
                    oldOffset: 2,
                    newOffset: 2,
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
                    oldOffset: 4,
                    newOffset: 4,
                    oldSnippet: [.init(text: "// divider a")],
                    newSnippet: [.init(text: "// divider a")]
                ),
                .init(
                    oldOffset: 5,
                    newOffset: 5,
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
                    oldOffset: 0,
                    newOffset: 0,
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
                    oldOffset: 2,
                    newOffset: 2,
                    oldSnippet: [.init(text: "// divider a")],
                    newSnippet: [.init(text: "// divider a")]
                ),
                .init(
                    oldOffset: 3,
                    newOffset: 3,
                    oldSnippet: [.init(
                        text: "print(foo)",
                        diff: .mutated(changes: [
                            .init(offset: 0, element: "print(foo)"),
                        ])
                    )],
                    newSnippet: []
                ),
                .init(
                    oldOffset: 4,
                    newOffset: 3,
                    oldSnippet: [.init(text: "// divider b")],
                    newSnippet: [.init(text: "// divider b")]
                ),
                .init(
                    oldOffset: 5,
                    newOffset: 4,
                    oldSnippet: [.init(
                        text: "print(foo)",
                        diff: .mutated(changes: [
                            .init(offset: 0, element: "print(foo)"),
                        ])
                    )],
                    newSnippet: []
                ),
                .init(
                    oldOffset: 6,
                    newOffset: 4,
                    oldSnippet: [.init(text: "// divider c")],
                    newSnippet: [.init(text: "// divider c")]
                ),
                .init(
                    oldOffset: 7,
                    newOffset: 5,
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

    func test_removing_last_line() {
        let originalCode = """
        1
        2
        3
        """
        let newCode = """
        1
        2
        """

        let diff = CodeDiff().diff(snippet: newCode, from: originalCode)
        XCTAssertEqual(diff, .init(sections: [
            .init(oldOffset: 0, newOffset: 0, oldSnippet: [
                .init(text: "1", diff: .unchanged),
                .init(text: "2", diff: .unchanged),
            ], newSnippet: [
                .init(text: "1", diff: .unchanged),
                .init(text: "2", diff: .unchanged),
            ]),
            .init(oldOffset: 2, newOffset: 2, oldSnippet: [
                .init(text: "3", diff: .mutated(changes: [.init(offset: 0, element: "3")])),
            ], newSnippet: [
            ]),
        ]))
    }

    func test_removing_multiple_sections() {
        let originalCode = """
        1
        2
        3
        4
        5
        """
        let newCode = """
        1
        3
        5
        """

        let diff = CodeDiff().diff(snippet: newCode, from: originalCode)
        XCTAssertEqual(diff, .init(sections: [
            .init(oldOffset: 0, newOffset: 0, oldSnippet: [
                .init(text: "1", diff: .unchanged),
            ], newSnippet: [
                .init(text: "1", diff: .unchanged),
            ]),
            .init(oldOffset: 1, newOffset: 1, oldSnippet: [
                .init(text: "2", diff: .mutated(changes: [.init(offset: 0, element: "2")])),
            ], newSnippet: [
            ]),
            .init(oldOffset: 2, newOffset: 1, oldSnippet: [
                .init(text: "3", diff: .unchanged),
            ], newSnippet: [
                .init(text: "3", diff: .unchanged),
            ]),
            .init(oldOffset: 3, newOffset: 2, oldSnippet: [
                .init(text: "4", diff: .mutated(changes: [.init(offset: 0, element: "4")])),
            ], newSnippet: [
            ]),
            .init(oldOffset: 4, newOffset: 2, oldSnippet: [
                .init(text: "5", diff: .unchanged),
            ], newSnippet: [
                .init(text: "5", diff: .unchanged),
            ]),
        ]))
    }
}

