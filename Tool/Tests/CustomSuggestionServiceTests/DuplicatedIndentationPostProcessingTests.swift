import Foundation
import XCTest

@testable import CustomSuggestionService

final class DuplicatedIndentationPostProcessingTests: XCTestCase {
    let strategy = DefaultRawSuggestionPostProcessingStrategy(
        codeWrappingTags: ("<Code3721>", "</Code3721>")
    )

    func test_dropsLeadingWhitespaceWhenThePrefixAlreadyEndsWithWhitespace() {
        let result = strategy.postProcess(
            rawSuggestion: "        ))\nlet shareItem = 1",
            infillPrefix: "/// ",
            suffix: []
        )
        XCTAssertEqual(result, "/// ))\nlet shareItem = 1")
    }

    func test_dropsExtraIndentationOnAnAutoIndentedEmptyLine() {
        let result = strategy.postProcess(
            rawSuggestion: "    let a = 1",
            infillPrefix: "        ",
            suffix: []
        )
        XCTAssertEqual(result, "        let a = 1")
    }

    func test_keepsLeadingWhitespaceWhenThePrefixIsEmpty() {
        let result = strategy.postProcess(rawSuggestion: "    let a = 1", infillPrefix: "", suffix: [])
        XCTAssertEqual(result, "    let a = 1")
    }

    func test_keepsLeadingWhitespaceWhenThePrefixEndsWithNonWhitespace() {
        let result = strategy.postProcess(rawSuggestion: " = 1", infillPrefix: "let a", suffix: [])
        XCTAssertEqual(result, "let a = 1")
    }

    func test_dropsTabsToo() {
        let result = strategy.postProcess(rawSuggestion: "\t\tfoo()", infillPrefix: "\t", suffix: [])
        XCTAssertEqual(result, "\tfoo()")
    }
}
