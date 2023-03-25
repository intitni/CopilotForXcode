import XCTest
@testable import Service

class RemoveContinuousSpacesInCodeTests: XCTestCase {
    func test_remove_continuous_spaces_in_code_empty_string() {
        let input = ""
        let expectedOutput = ""
        let output = removeContinuousSpaces(from: input)
        XCTAssertEqual(output, expectedOutput)
    }
    
    func test_remove_continuous_spaces_in_code_blank_string() {
        let input = "   "
        let expectedOutput = ""
        let output = removeContinuousSpaces(from: input)
        XCTAssertEqual(output, expectedOutput)
    }
    
    func test_remove_continuous_spaces() {
        let input = "hello    world"
        let expectedOutput = "hello world"
        let output = removeContinuousSpaces(from: input)
        XCTAssertEqual(output, expectedOutput)
    }
    
    func test_remove_continuous_spaces_without_continuous_spaces() {
        let input = "hello world"
        let expectedOutput = "hello world"
        let output = removeContinuousSpaces(from: input)
        XCTAssertEqual(output, expectedOutput)
    }
}

