import Foundation
import XCTest

@testable import SuggestionBasic

class LineAnnotationParsingTests: XCTestCase {
    func test_parse_line_annotation() {
        let annotation = "Error Line 25: FileName.swift:25 Cannot convert Type"
        let parsed = EditorInformation.parseLineAnnotation(annotation)
        XCTAssertEqual(parsed.type, "Error")
        XCTAssertEqual(parsed.line, 25)
        XCTAssertEqual(parsed.message, "Cannot convert Type")
    }
}
