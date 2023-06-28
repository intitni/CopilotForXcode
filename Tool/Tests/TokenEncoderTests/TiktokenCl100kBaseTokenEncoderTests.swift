import Foundation
import XCTest

@testable import TokenEncoder

class TiktokenCl100kBaseTokenEncoderTests: XCTestCase {
    func test_encoding() async throws {
        let encoder = TiktokenCl100kBaseTokenEncoder()
        let encoded = encoder.encode(text: "hello world")
        XCTAssertEqual(encoded, [15339, 1917])
    }
}
