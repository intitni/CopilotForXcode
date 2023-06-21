import PythonHelper
import XCTest

@testable import LangChain

final class RecursiveCharacterTextSplitterTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        await initializePython()
    }

    func test_split_text() async throws {
        let splitter = RecursiveCharacterTextSplitter(
            separators: ["\n\n", "\n", " ", ""],
            chunkSize: 100,
            chunkOverlap: 20
        )

        let text = """
        Madam Speaker, Madam Vice President, our First Lady and Second Gentleman. Members of Congress and the Cabinet. Justices of the Supreme Court. My fellow Americans.
        """

        let result = try await splitter.split(text: text)

        XCTAssertEqual(result, [
            "Madam Speaker, Madam Vice President, our First Lady and Second Gentleman. Members of Congress and",
            "of Congress and the Cabinet. Justices of the Supreme Court. My fellow Americans."
        ])
    }
}

