import Foundation
import AIModel
import XCTest

@testable import CustomSuggestionService

class DefaultRequestStrategyTests: XCTestCase {
    func test_source_prompt_creation_empty_suffix() {
        let prefix = """
        print("1")
        print("2")
        print("3")
        print("4")
        print("5")
        print("6")
        print("7")
        print("8")
        print("9")
        print("10")
        print("11")
        print("12")
        print("13")
        print("14")
        print("15")
        let cat:
        """

        guard let (summary, infillBlock) = DefaultRequestStrategy.Prompt.createCodeSummary(
            truncatedPrefix: prefix.breakLines(),
            truncatedSuffix: [], 
            suggestionPrefix: "let cat:"
        ) else {
            XCTFail()
            return
        }

        XCTAssertEqual(summary, """
        print("1")
        print("2")
        print("3")
        print("4")
        print("5")
        print("6")
        <Code3721></Code3721>
        """)
        XCTAssertEqual(infillBlock, """
        print("7")
        print("8")
        print("9")
        print("10")
        print("11")
        print("12")
        print("13")
        print("14")
        print("15")
        let cat:
        """, "At most 10 lines")
    }

    func test_source_prompt_creation_has_suffix() {
        let prefix = """
        print("1")
        print("2")
        print("3")
        print("4")
        print("5")
        print("6")
        print("7")
        print("8")
        print("9")
        print("10")
        print("11")
        print("12")
        print("13")
        print("14")
        print("15")
        let cat:
        """
        
        let suffix = """
        
        print("1")
        print("2")
        print("3")
        print("4")
        print("5")
        """

        guard let (summary, infillBlock) = DefaultRequestStrategy.Prompt.createCodeSummary(
            truncatedPrefix: prefix.breakLines(),
            truncatedSuffix: suffix.breakLines(),
            suggestionPrefix: "let cat:"
        ) else {
            XCTFail()
            return
        }

        XCTAssertEqual(summary, """
        print("1")
        print("2")
        print("3")
        print("4")
        print("5")
        print("6")
        <Code3721></Code3721>
        print("1")
        print("2")
        print("3")
        print("4")
        print("5")
        """)
        XCTAssertEqual(infillBlock, """
        print("7")
        print("8")
        print("9")
        print("10")
        print("11")
        print("12")
        print("13")
        print("14")
        print("15")
        let cat:
        """, "At most 10 lines")
    }
}

