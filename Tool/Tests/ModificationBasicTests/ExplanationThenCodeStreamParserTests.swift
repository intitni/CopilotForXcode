import Foundation
import XCTest
@testable import ModificationBasic

class ExplanationThenCodeStreamParserTests: XCTestCase {
    func collectFragments(_ fragments: [ExplanationThenCodeStreamParser.Fragment]) -> (
        code: String,
        explanation: String
    ) {
        var code = ""
        var explanation = ""
        for fragment in fragments {
            switch fragment {
            case let .code(c):
                code += c
            case let .explanation(e):
                explanation += e
            }
        }
        return (code: code, explanation: explanation)
    }

    func process(_ code: String) async -> (code: String, explanation: String) {
        let parser = ExplanationThenCodeStreamParser()
        var allFragments: [ExplanationThenCodeStreamParser.Fragment] = []

        func chunks(from code: String, chunkSize: Int) -> [String] {
            var chunks: [String] = []
            var currentIndex = code.startIndex

            while currentIndex < code.endIndex {
                let endIndex = code.index(
                    currentIndex,
                    offsetBy: chunkSize,
                    limitedBy: code.endIndex
                ) ?? code.endIndex
                let chunk = String(code[currentIndex..<endIndex])
                chunks.append(chunk)
                currentIndex = endIndex
            }

            return chunks
        }

        for chunk in chunks(from: code, chunkSize: 8) {
            let output = await parser.yield(chunk)
            allFragments.append(contentsOf: output)
        }

        await allFragments.append(contentsOf: parser.finish())

        return collectFragments(allFragments)
    }

    func test_parse_only_explanation() async throws {
        let (code, explanation) = await process("""
        Hello World!
        Hello World!


        """)

        XCTAssertEqual(code, "")
        XCTAssertEqual(explanation, "Hello World!\nHello World!")
    }

    func test_parse_only_code() async throws {
        let (code, explanation) = await process("""
        ```swift
        struct Cat {
            var name: String
        }

        print("Hello world!")


        ```
        """)

        XCTAssertEqual(code, """
        struct Cat {
            var name: String
        }

        print("Hello world!")


        """)
        XCTAssertEqual(explanation, "")
    }

    func test_parse_mixed_explanation_and_code() async throws {
        let (code, explanation) = await process("""
        Here is the explanation of the code change.


        ```swift
        struct Cat {
            var name: String
        }
        ```
        """)

        XCTAssertEqual(code, """
        struct Cat {
            var name: String
        }
        """)
        XCTAssertEqual(explanation, """
        Here is the explanation of the code change.
        """)
    }

    func test_parse_mixed_explanation_contains_code_delimiters() async throws {
        let (code, explanation) = await process("""
        Use ``` for code blocks. Use ` for inline code.


        ```swift
        struct Cat {
            var name: String
        }
        ```
        """)

        XCTAssertEqual(code, """
        struct Cat {
            var name: String
        }
        """)
        XCTAssertEqual(explanation, """
        Use ``` for code blocks. Use ` for inline code.
        """)
    }

    func test_parse_extra_content_after_code_block_should_ignore_the_extra() async throws {
        let (code, explanation) = await process("""
        Hello World!

        ```swift
        print("Hello, world!")
        print("Hello, world!")
        ```
        Hello

        """)

        XCTAssertEqual(code, """
        print("Hello, world!")
        print("Hello, world!")
        """)
        XCTAssertEqual(explanation, "Hello World!")
    }

    func test_parse_incomplete_code_block() async throws {
        let (code, explanation) = await process("""
        Here is some explanation.

        ```swift
        struct Cat {
            var name: String


        """)

        XCTAssertEqual(code, """
        struct Cat {
            var name: String


        """)
        XCTAssertEqual(explanation, "Here is some explanation.")
    }

    func test_parse_extra_code_block_cant_tell() async throws {
        let (code, explanation) = await process("""
        ```swift
        struct Cat {
            var name: String
        }
        ```

        ```swift
        struct Cat {
            var name: String
        }
        ```
        """)

        XCTAssertEqual(code, """
        struct Cat {
            var name: String
        }
        ```

        ```swift
        struct Cat {
            var name: String
        }
        """)
        XCTAssertEqual(explanation, "")
    }

    func test_parse_extra_code_block_no_language_name_cant_tell() async throws {
        let (code, explanation) = await process("""
        ```swift
        struct Cat {
            var name: String
        }
        ```

        ```
        struct Cat {
            var name: String
        }
        ```
        """)

        XCTAssertEqual(code, """
        struct Cat {
            var name: String
        }
        ```

        ```
        struct Cat {
            var name: String
        }
        """)
        XCTAssertEqual(explanation, "")
    }

    func test_code_delimiters_within_code_block_with_indentation() async throws {
        let (code, explanation) = await process("""
        Here is some explanation.

        ```swift
        let codeBlock = \"""
            ```plaintext
            code
            ```
            \"""

        print("Hello world!")
        ```
        """)

        XCTAssertEqual(code, """
        let codeBlock = \"""
            ```plaintext
            code
            ```
            \"""

        print("Hello world!")
        """)
        XCTAssertEqual(explanation, "Here is some explanation.")
    }

    func test_code_delimiters_within_code_block() async throws {
        let (code, explanation) = await process("""
        Here is some explanation.

        ```swift
        let codeBlock = \"""
        ```plaintext
        code
        ```
        \"""

        print("Hello world!")
        ```

        End.
        """)

        XCTAssertEqual(code, """
        let codeBlock = \"""
        ```plaintext
        code
        ```
        \"""

        print("Hello world!")
        """)
        XCTAssertEqual(explanation, "Here is some explanation.")
    }
}

