import XCTest

@testable import SharedUIComponents

final class ConvertToCodeLinesTests: XCTestCase {
    func test_do_not_remove_common_leading_spaces() async throws {
        let code = """
            struct Cat {
            }
        """
        let (result, spaceCount) = CodeHighlighting.highlighted(
            code: code,
            language: "swift",
            scenario: "a",
            brightMode: true,
            droppingLeadingSpaces: false,
            font: .systemFont(ofSize: 14)
        )

        XCTAssertEqual(spaceCount, 0)
        print(code.replacingOccurrences(of: " ", with: "·"))
        XCTAssertEqual(result.map(\.string), [
            "····struct·Cat·{",
            "····}",
        ])
    }
    
    func test_wont_remove_common_leading_spaces_2_spaces() async throws {
        let code = """
          struct Cat {
            }
        """
        let (result, spaceCount) = CodeHighlighting.highlighted(
            code: code,
            language: "md",
            scenario: "a",
            brightMode: true,
            droppingLeadingSpaces: true,
            font: .systemFont(ofSize: 14)
        )

        XCTAssertEqual(spaceCount, 0)
        XCTAssertEqual(result.map(\.string), [
            "··struct·Cat·{",
            "····}",
        ])
    }
    
    func test_remove_common_leading_spaces_4_spaces() async throws {
        let code = """
            struct Cat {
            }
        """
        let (result, spaceCount) = CodeHighlighting.highlighted(
            code: code,
            language: "md",
            scenario: "a",
            brightMode: true,
            droppingLeadingSpaces: true,
            font: .systemFont(ofSize: 14)
        )

        XCTAssertEqual(spaceCount, 4)
        XCTAssertEqual(result.map(\.string), [
            "struct·Cat·{",
            "}",
        ])
    }
    
    func test_remove_common_leading_spaces_8_spaces() async throws {
        let code = """
                struct Cat {
                }
        """
        let (result, spaceCount) = CodeHighlighting.highlighted(
            code: code,
            language: "md",
            scenario: "a",
            brightMode: true,
            droppingLeadingSpaces: true,
            font: .systemFont(ofSize: 14)
        )

        XCTAssertEqual(spaceCount, 8)
        XCTAssertEqual(result.map(\.string), [
            "struct·Cat·{",
            "}",
        ])
    }

    func test_remove_common_leading_spaces_one_line_is_empty() async throws {
        let code = """
            struct Cat {

            }
        """
        let (result, spaceCount) = CodeHighlighting.highlighted(
            code: code,
            language: "md",
            scenario: "a",
            brightMode: true,
            droppingLeadingSpaces: true,
            font: .systemFont(ofSize: 14)
        )

        XCTAssertEqual(spaceCount, 4)
        XCTAssertEqual(result.map(\.string), [
            "struct·Cat·{",
            "",
            "}",
        ])
    }
    
    func test_remove_common_leading_spaces_one_line_has_no_leading_spaces() async throws {
        let code = """
            struct Cat {
        //
            }
        """
        let (result, spaceCount) = CodeHighlighting.highlighted(
            code: code,
            language: "md",
            scenario: "a",
            brightMode: true,
            droppingLeadingSpaces: true,
            font: .systemFont(ofSize: 14)
        )

        XCTAssertEqual(spaceCount, 0)
        XCTAssertEqual(result.map(\.string), [
            "····struct·Cat·{",
            "//",
            "····}",
        ])
    }
    
    func test_remove_common_leading_spaces_one_line_has_fewer_leading_spaces() async throws {
        let code = """
                struct Cat {
            //
                }
        """
        let (result, spaceCount) = CodeHighlighting.highlighted(
            code: code,
            language: "md",
            scenario: "a",
            brightMode: true,
            droppingLeadingSpaces: true,
            font: .systemFont(ofSize: 14)
        )

        XCTAssertEqual(spaceCount, 4)
        XCTAssertEqual(result.map(\.string), [
            "····struct·Cat·{",
            "//",
            "····}",
        ])
    }
}
