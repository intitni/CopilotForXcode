import XCTest

@testable import SuggestionWidget

final class ConvertToCodeLinesTests: XCTestCase {
    func test_do_not_remove_common_leading_spaces() async throws {
        let code = """
            struct Cat {
            }
        """
        let (result, spaceCount) = highlighted(
            code: code,
            language: "swift",
            brightMode: true,
            droppingLeadingSpaces: false
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
        let (result, spaceCount) = highlighted(
            code: code,
            language: "md",
            brightMode: true,
            droppingLeadingSpaces: true
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
        let (result, spaceCount) = highlighted(
            code: code,
            language: "md",
            brightMode: true,
            droppingLeadingSpaces: true
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
        let (result, spaceCount) = highlighted(
            code: code,
            language: "md",
            brightMode: true,
            droppingLeadingSpaces: true
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
        let (result, spaceCount) = highlighted(
            code: code,
            language: "md",
            brightMode: true,
            droppingLeadingSpaces: true
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
        let (result, spaceCount) = highlighted(
            code: code,
            language: "md",
            brightMode: true,
            droppingLeadingSpaces: true
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
        let (result, spaceCount) = highlighted(
            code: code,
            language: "md",
            brightMode: true,
            droppingLeadingSpaces: true
        )

        XCTAssertEqual(spaceCount, 4)
        XCTAssertEqual(result.map(\.string), [
            "····struct·Cat·{",
            "//",
            "····}",
        ])
    }
}
