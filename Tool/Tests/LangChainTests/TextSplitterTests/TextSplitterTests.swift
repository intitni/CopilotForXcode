import XCTest

@testable import LangChain

final class TextSplitterTests: XCTestCase {
    struct Splitter: TextSplitter {
        var chunkSize: Int
        var chunkOverlap: Int
        var lengthFunction: (String) -> Int = { $0.count }
        func split(text: String) async throws -> [String] {
            []
        }
    }

    func test_split_text_with_text_separator() async throws {
        let splitter = Splitter(
            chunkSize: 1,
            chunkOverlap: 1
        )

        let result = splitter.split(
            text: "Madam Speaker, Madam Vice President, our First",
            separator: " "
        )

        XCTAssertEqual(
            result,
            ["Madam", " Speaker,", " Madam", " Vice", " President,", " our", " First"]
        )
    }

    func test_split_text_with_regex_separator() async throws {
        let splitter = Splitter(
            chunkSize: 1,
            chunkOverlap: 1
        )

        let result = splitter.split(
            text: "Madam Speaker, Madam Vice President, our First",
            separator: "\\s\\w\\w\\w\\w\\s" // split at " Vice "
        )

        XCTAssertEqual(
            result,
            ["Madam Speaker, Madam", " Vice President, our First"]
        )
    }

    func test_merge_splits() async throws {
        let splitter = Splitter(
            chunkSize: 15,
            chunkOverlap: 5
        )

        let result = splitter.mergeSplits(
            ["Madam", " Speaker,", " Madam", " Vice", " President,", " our", " First"]
        )

        XCTAssertEqual(
            result,
            ["Madam Speaker,", "Madam Vice", "President, our", "our First"]
        )
        XCTAssertTrue(result.allSatisfy { $0.count <= 15 })
    }
}

