import XCTest

@testable import LangChain

final class TextSplitterTests: XCTestCase {
    struct Splitter: TextSplitter {
        var chunkSize: Int
        var chunkOverlap: Int
        var lengthFunction: (String) -> Int = { $0.count }
        func split(text: String) async throws -> [TextChunk] {
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
            [
                .init(text: "Madam", startUTF16Offset: 0, endUTF16Offset: 5),
                .init(text: " Speaker,", startUTF16Offset: 5, endUTF16Offset: 14),
                .init(text: " Madam", startUTF16Offset: 14, endUTF16Offset: 20),
                .init(text: " Vice", startUTF16Offset: 20, endUTF16Offset: 25),
                .init(text: " President,", startUTF16Offset: 25, endUTF16Offset: 36),
                .init(text: " our", startUTF16Offset: 36, endUTF16Offset: 40),
                .init(text: " First", startUTF16Offset: 40, endUTF16Offset: 46),
            ]
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
            [
                .init(text: "Madam Speaker, Madam", startUTF16Offset: 0, endUTF16Offset: 20),
                .init(text: " Vice President, our First", startUTF16Offset: 20, endUTF16Offset: 46),
            ]
        )
    }

    func test_merge_splits() async throws {
        let splitter = Splitter(
            chunkSize: 15,
            chunkOverlap: 5
        )

        let result = splitter.mergeSplits(
            [
                .init(text: "Madam", startUTF16Offset: 0, endUTF16Offset: 5),
                .init(text: " Speaker,", startUTF16Offset: 5, endUTF16Offset: 14),
                .init(text: " Madam", startUTF16Offset: 14, endUTF16Offset: 20),
                .init(text: " Vice", startUTF16Offset: 20, endUTF16Offset: 25),
                .init(text: " President,", startUTF16Offset: 25, endUTF16Offset: 36),
                .init(text: " our", startUTF16Offset: 36, endUTF16Offset: 40),
                .init(text: " First", startUTF16Offset: 40, endUTF16Offset: 46),
            ]
        )

        XCTAssertEqual(
            result,
            [
                .init(text: "Madam Speaker,", startUTF16Offset: 0, endUTF16Offset: 14),
                .init(text: " Madam Vice", startUTF16Offset: 14, endUTF16Offset: 25),
                .init(text: " President, our", startUTF16Offset: 25, endUTF16Offset: 40),
                .init(text: " our First", startUTF16Offset: 36, endUTF16Offset: 46),
            ]
        )
        XCTAssertTrue(result.allSatisfy { $0.text.count <= 15 })
    }
}

