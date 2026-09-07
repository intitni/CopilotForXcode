import Foundation
import XCTest

@testable import CustomSuggestionService

class DefaultRawSuggestionPostProcessingStrategyTests: XCTestCase {
    func test_whenSuggestionHasCodeTagAtTheFirstLine_shouldExtractCodeInside() {
        let strategy = DefaultRawSuggestionPostProcessingStrategy(
            codeWrappingTags: ("<Code>", "</Code>")
        )
        let result = strategy.extractSuggestion(
            from: """
            <Code>suggestion</Code>
            """
        )

        XCTAssertEqual(result, "suggestion")
    }

    func test_whenSuggestionHasCodeTagAtTheFirstLine_closingTagInOtherLines_shouldExtractCodeInside(
    ) {
        let strategy = DefaultRawSuggestionPostProcessingStrategy(
            codeWrappingTags: ("<Code>", "</Code>")
        )
        let result = strategy.extractSuggestion(
            from: """
            <Code>suggestion
            yes</Code>
            """
        )

        XCTAssertEqual(result, "suggestion\nyes")
    }

    func test_whenSuggestionHasCodeTag_butNoClosingTag_shouldExtractCodeAfterTheTag() {
        let strategy = DefaultRawSuggestionPostProcessingStrategy(
            codeWrappingTags: ("<Code>", "</Code>")
        )
        let result = strategy.extractSuggestion(
            from: """
            <Code>suggestion
            yes
            """
        )

        XCTAssertEqual(result, "suggestion\nyes")
    }

    func test_whenMultipleOpeningTagFound_shouldTreatTheNextOneAsClosing() {
        let strategy = DefaultRawSuggestionPostProcessingStrategy(
            codeWrappingTags: ("<Code>", "</Code>")
        )
        let result = strategy.extractSuggestion(
            from: """
            <Code>suggestion<Code>hello<Code><Code><Code><Code>
            """
        )
        XCTAssertEqual(result, "suggestion")
    }

    func test_whenMarkdownCodeBlockFound_shouldExtractCodeInside() {
        let strategy = DefaultRawSuggestionPostProcessingStrategy(
            codeWrappingTags: ("<Code>", "</Code>")
        )
        let result = strategy.extractSuggestion(
            from: """
            ```language
            suggestion
            ```
            """
        )

        XCTAssertEqual(result, "suggestion\n")
    }

    func test_whenOnlyLinebreaksOrSpacesBeforeMarkdownCodeBlock_shouldExtractCodeInside() {
        let strategy = DefaultRawSuggestionPostProcessingStrategy(
            codeWrappingTags: ("<Code>", "</Code>")
        )
        let result = strategy.extractSuggestion(
            from: """


                 ```
            suggestion
            ```
            """
        )

        XCTAssertEqual(result, "suggestion\n")

        let result2 = strategy.extractSuggestion(
            from: """
                    ```
            suggestion
            ```
            """
        )

        XCTAssertEqual(result2, "suggestion\n")

        let result3 = strategy.extractSuggestion(
            from: """


            ```
            suggestion
            ```
            """
        )

        XCTAssertEqual(result3, "suggestion\n")
    }

    func test_whenMarkdownCodeBlockAndCodeTagFound_firstlyExtractCodeTag_thenCodeTag() {
        let strategy = DefaultRawSuggestionPostProcessingStrategy(
            codeWrappingTags: ("<Code>", "</Code>")
        )
        let result = strategy.extractSuggestion(
            from: """
            ```language
            <Code>suggestion</Code>
            suggestion
            ```
            """
        )
        XCTAssertEqual(result, "suggestion")
    }

    func test_whenMarkdownCodeBlockAndCodeTagFound_butNoClosingTag_firstlyExtractCodeTag_thenCodeTag(
    ) {
        let strategy = DefaultRawSuggestionPostProcessingStrategy(
            codeWrappingTags: ("<Code>", "</Code>")
        )
        let result = strategy.extractSuggestion(
            from: """
            ```language
            <Code>suggestion
            suggestion
            ```
            """
        )
        XCTAssertEqual(result, "suggestion\nsuggestion\n")
    }

    func test_whenSuggestionHasTheSamePrefix_removeThePrefix() {
        let strategy = DefaultRawSuggestionPostProcessingStrategy(
            codeWrappingTags: ("<Code>", "</Code>")
        )
        let result = strategy.extractSuggestion(
            from: "suggestion"
        )

        XCTAssertEqual(result, "suggestion")
    }

    func test_whenSuggestionLooksLikeAMessage_parseItCorrectly() {
        let strategy = DefaultRawSuggestionPostProcessingStrategy(
            codeWrappingTags: ("<Code>", "</Code>")
        )
        let result = strategy.extractSuggestion(
            from: """
            Here is the suggestion:
            ```language
            suggestion
            ```
            """
        )

        XCTAssertEqual(result, "suggestion\n")
    }

    func test_whenSuggestionHasTheSamePrefix_inTags_removeThePrefix() {
        let strategy = DefaultRawSuggestionPostProcessingStrategy(
            codeWrappingTags: ("<Code>", "</Code>")
        )
        var suggestion = "prefix suggestion"
        strategy.removePrefix(from: &suggestion, infillPrefix: "prefix")

        XCTAssertEqual(suggestion, " suggestion")
    }

    func test_whenSuggestionHasTheSameSuffix_removeTheSuffix() {
        let strategy = DefaultRawSuggestionPostProcessingStrategy(
            codeWrappingTags: ("<Code>", "</Code>")
        )
        var suggestion = "suggestion\na\nb"
        strategy.removeSuffix(from: &suggestion, suffix: [
            "a\n",
            "b\n",
        ])

        XCTAssertEqual(suggestion, "suggestion\n")

        var suggestion2 = "suggestion\na\nb"
        strategy.removeSuffix(from: &suggestion2, suffix: [])

        XCTAssertEqual(suggestion2, "suggestion\na\nb")

        var suggestion3 = "suggestion\na\nb"
        strategy.removeSuffix(from: &suggestion3, suffix: ["b\n"])

        XCTAssertEqual(suggestion3, "suggestion\na\n")
    }

    func test_case_1() {
        let strategy = DefaultRawSuggestionPostProcessingStrategy(
            codeWrappingTags: ("<Code>", "</Code>")
        )
        let result = strategy.postProcess(
            rawSuggestion: """
            ```language
            <Code>prefix suggestion</Code>
            a
            b
            c
            ```
            """,
            infillPrefix: "prefix",
            suffix: ["a\n", "b\n", "c\n"]
        )
        XCTAssertEqual(result, "prefix suggestion")
    }
}

