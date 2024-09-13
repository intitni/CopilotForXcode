import Foundation
import SuggestionBasic
import XCTest

@testable import SuggestionProvider

class PostProcessingSuggestionServiceMiddlewareTests: XCTestCase {
    func createRequest(
        _ code: String = "",
        _ cursorPosition: CursorPosition = .zero
    ) -> SuggestionRequest {
        let lines = code.breakLines()
        return SuggestionRequest(
            fileURL: URL(fileURLWithPath: "/path/to/file.swift"),
            relativePath: "file.swift",
            content: code, 
            originalContent: code,
            lines: lines,
            cursorPosition: cursorPosition,
            cursorOffset: {
                if cursorPosition == .outOfScope { return 0 }
                let prefixLines = if cursorPosition.line > 0 {
                    lines[0..<cursorPosition.line]
                } else {
                    [] as ArraySlice<String>
                }
                let offset = prefixLines.reduce(0) { $0 + $1.utf8.count }
                return offset
                    + lines[cursorPosition.line].prefix(cursorPosition.character).utf8.count
            }(),
            tabSize: 4,
            indentSize: 4,
            usesTabsForIndentation: false,
            relevantCodeSnippets: []
        )
    }
    
    func test_empty() async throws {
        let middleware = PostProcessingSuggestionServiceMiddleware()

        let handler: PostProcessingSuggestionServiceMiddleware.Next = { _ in
            [
                .init(
                    id: "1",
                    text: "",
                    position: .init(line: 0, character: 0),
                    range: .init(startPair: (0, 0), endPair: (0, 0))
                ),
            ]
        }

        let suggestions = try await middleware.getSuggestion(
            createRequest("", .init(line: 0, character: 0)),
            configuration: .init(
                acceptsRelevantCodeSnippets: true,
                mixRelevantCodeSnippetsInSource: true,
                acceptsRelevantSnippetsFromOpenedFiles: true
            ),
            next: handler
        )

        XCTAssertEqual(suggestions, [])
    }

    func test_trailing_whitespaces_and_new_lines_should_be_removed() async throws {
        let middleware = PostProcessingSuggestionServiceMiddleware()

        let handler: PostProcessingSuggestionServiceMiddleware.Next = { _ in
            [
                .init(
                    id: "1",
                    text: "hello world \n   \n",
                    position: .init(line: 0, character: 0),
                    range: .init(startPair: (0, 0), endPair: (0, 0))
                ),
                .init(
                    id: "2",
                    text: "  \n  hello world \n   \n",
                    position: .init(line: 0, character: 0),
                    range: .init(startPair: (0, 0), endPair: (0, 0))
                ),
            ]
        }

        let suggestions = try await middleware.getSuggestion(
            createRequest(),
            configuration: .init(
                acceptsRelevantCodeSnippets: true,
                mixRelevantCodeSnippetsInSource: true,
                acceptsRelevantSnippetsFromOpenedFiles: true
            ),
            next: handler
        )

        XCTAssertEqual(suggestions, [
            .init(
                id: "1",
                text: "hello world",
                position: .init(line: 0, character: 0),
                range: .init(startPair: (0, 0), endPair: (0, 0))
            ),
            .init(
                id: "2",
                text: "  \n  hello world",
                position: .init(line: 0, character: 0),
                range: .init(startPair: (0, 0), endPair: (0, 0))
            ),
        ])
    }

    func test_remove_suggestions_that_contains_only_whitespaces_and_new_lines() async throws {
        let middleware = PostProcessingSuggestionServiceMiddleware()

        let handler: PostProcessingSuggestionServiceMiddleware.Next = { _ in
            [
                .init(
                    id: "1",
                    text: "hello world \n   \n",
                    position: .init(line: 0, character: 0),
                    range: .init(startPair: (0, 0), endPair: (0, 0))
                ),
                .init(
                    id: "2",
                    text: "     \n\n\r",
                    position: .init(line: 0, character: 0),
                    range: .init(startPair: (0, 0), endPair: (0, 0))
                ),
                .init(
                    id: "3",
                    text: "   ",
                    position: .init(line: 0, character: 0),
                    range: .init(startPair: (0, 0), endPair: (0, 0))
                ),
                .init(
                    id: "4",
                    text: "\n\n\n",
                    position: .init(line: 0, character: 0),
                    range: .init(startPair: (0, 0), endPair: (0, 0))
                ),
            ]
        }

        let suggestions = try await middleware.getSuggestion(
            createRequest(),
            configuration: .init(
                acceptsRelevantCodeSnippets: true,
                mixRelevantCodeSnippetsInSource: true,
                acceptsRelevantSnippetsFromOpenedFiles: true
            ),
            next: handler
        )

        XCTAssertEqual(suggestions, [
            .init(
                id: "1",
                text: "hello world",
                position: .init(line: 0, character: 0),
                range: .init(startPair: (0, 0), endPair: (0, 0))
            ),
        ])
    }
    
    func test_remove_suggestion_that_takes_no_effect_after_being_accepted() async throws {
        let middleware = PostProcessingSuggestionServiceMiddleware()

        let handler: PostProcessingSuggestionServiceMiddleware.Next = { _ in
            [
                .init(
                    id: "1",
                    text: "hello world \n   \n",
                    position: .init(line: 0, character: 0),
                    range: .init(startPair: (0, 0), endPair: (0, 0))
                ),
                .init(
                    id: "2",
                    text: "let cat = 100",
                    position: .init(line: 0, character: 13),
                    range: .init(startPair: (0, 0), endPair: (0, 13))
                ),
                .init(
                    id: "3",
                    text: "let cat = 10",
                    position: .init(line: 0, character: 13),
                    range: .init(startPair: (0, 0), endPair: (0, 13))
                ),
            ]
        }

        let suggestions = try await middleware.getSuggestion(
            createRequest("let cat = 100", .init(line: 0, character: 3)),
            configuration: .init(
                acceptsRelevantCodeSnippets: true,
                mixRelevantCodeSnippetsInSource: true,
                acceptsRelevantSnippetsFromOpenedFiles: true
            ),
            next: handler
        )

        XCTAssertEqual(suggestions, [
            .init(
                id: "1",
                text: "hello world",
                position: .init(line: 0, character: 0),
                range: .init(startPair: (0, 0), endPair: (0, 0))
            ),
            .init(
                id: "3",
                text: "let cat = 10",
                position: .init(line: 0, character: 13),
                range: .init(startPair: (0, 0), endPair: (0, 13))
            ),
        ])
    }
    
    func test_remove_duplicated_trailing_closing_parenthesis_single_parenthesis() async throws {
        let middleware = PostProcessingSuggestionServiceMiddleware()

        let handler: PostProcessingSuggestionServiceMiddleware.Next = { _ in
            [
                .init(
                    id: "1",
                    text: "hello world\n}",
                    position: .init(line: 0, character: 1),
                    range: .init(startPair: (0, 0), endPair: (0, 1))
                ),
            ]
        }

        let suggestions = try await middleware.getSuggestion(
            createRequest("h\n}\n", .init(line: 0, character: 1)),
            configuration: .init(
                acceptsRelevantCodeSnippets: true,
                mixRelevantCodeSnippetsInSource: true,
                acceptsRelevantSnippetsFromOpenedFiles: true
            ),
            next: handler
        )

        XCTAssertEqual(suggestions, [
            .init(
                id: "1",
                text: "hello world",
                position: .init(line: 0, character: 1),
                range: .init(startPair: (0, 0), endPair: (0, 1)),
                middlewareComments: ["Removed redundant closing parenthesis."]
            ),
        ])
    }
    
    func test_remove_duplicated_trailing_closing_parenthesis_single_line() async throws {
        let middleware = PostProcessingSuggestionServiceMiddleware()

        let handler: PostProcessingSuggestionServiceMiddleware.Next = { _ in
            [
                .init(
                    id: "1",
                    text: "}",
                    position: .init(line: 0, character: 0),
                    range: .init(startPair: (0, 0), endPair: (0, 0))
                ),
            ]
        }

        let suggestions = try await middleware.getSuggestion(
            createRequest("\n}\n", .init(line: 0, character: 0)),
            configuration: .init(
                acceptsRelevantCodeSnippets: true,
                mixRelevantCodeSnippetsInSource: true,
                acceptsRelevantSnippetsFromOpenedFiles: true
            ),
            next: handler
        )

        XCTAssertEqual(suggestions, [
            .init(
                id: "1",
                text: "",
                position: .init(line: 0, character: 0),
                range: .init(startPair: (0, 0), endPair: (0, 0)),
                middlewareComments: ["Removed redundant closing parenthesis."]
            ),
        ])
    }
    
    func test_remove_duplicated_trailing_closing_parenthesis_leading_space() async throws {
        let middleware = PostProcessingSuggestionServiceMiddleware()

        let handler: PostProcessingSuggestionServiceMiddleware.Next = { _ in
            [
                .init(
                    id: "1",
                    text: "hello world\n    }",
                    position: .init(line: 0, character: 1),
                    range: .init(startPair: (0, 0), endPair: (0, 1))
                ),
            ]
        }

        let suggestions = try await middleware.getSuggestion(
            createRequest("h\n    }\n", .init(line: 0, character: 1)),
            configuration: .init(
                acceptsRelevantCodeSnippets: true,
                mixRelevantCodeSnippetsInSource: true,
                acceptsRelevantSnippetsFromOpenedFiles: true
            ),
            next: handler
        )

        XCTAssertEqual(suggestions, [
            .init(
                id: "1",
                text: "hello world",
                position: .init(line: 0, character: 1),
                range: .init(startPair: (0, 0), endPair: (0, 1)),
                middlewareComments: ["Removed redundant closing parenthesis."]
            ),
        ])
    }
    
    func test_remove_duplicated_trailing_closing_parenthesis_commas() async throws {
        let middleware = PostProcessingSuggestionServiceMiddleware()

        let handler: PostProcessingSuggestionServiceMiddleware.Next = { _ in
            [
                .init(
                    id: "1",
                    text: "hello world\n,},",
                    position: .init(line: 0, character: 1),
                    range: .init(startPair: (0, 0), endPair: (0, 1))
                ),
            ]
        }

        let suggestions = try await middleware.getSuggestion(
            createRequest("h\n,},\n", .init(line: 0, character: 1)),
            configuration: .init(
                acceptsRelevantCodeSnippets: true,
                mixRelevantCodeSnippetsInSource: true,
                acceptsRelevantSnippetsFromOpenedFiles: true
            ),
            next: handler
        )

        XCTAssertEqual(suggestions, [
            .init(
                id: "1",
                text: "hello world",
                position: .init(line: 0, character: 1),
                range: .init(startPair: (0, 0), endPair: (0, 1)),
                middlewareComments: ["Removed redundant closing parenthesis."]
            ),
        ])
    }
    
    func test_remove_duplicated_trailing_closing_parenthesis_multiple_parenthesis() async throws {
        let middleware = PostProcessingSuggestionServiceMiddleware()

        let handler: PostProcessingSuggestionServiceMiddleware.Next = { _ in
            [
                .init(
                    id: "1",
                    text: "hello world\n}))>}}",
                    position: .init(line: 0, character: 1),
                    range: .init(startPair: (0, 0), endPair: (0, 1))
                ),
            ]
        }

        let suggestions = try await middleware.getSuggestion(
            createRequest("h\n}))>}}\n", .init(line: 0, character: 1)),
            configuration: .init(
                acceptsRelevantCodeSnippets: true,
                mixRelevantCodeSnippetsInSource: true,
                acceptsRelevantSnippetsFromOpenedFiles: true
            ),
            next: handler
        )

        XCTAssertEqual(suggestions, [
            .init(
                id: "1",
                text: "hello world",
                position: .init(line: 0, character: 1),
                range: .init(startPair: (0, 0), endPair: (0, 1)),
                middlewareComments: ["Removed redundant closing parenthesis."]
            ),
        ])
    }
}

