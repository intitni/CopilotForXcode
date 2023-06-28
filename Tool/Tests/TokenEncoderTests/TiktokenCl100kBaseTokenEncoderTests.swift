import Foundation
import XCTest

@testable import TokenEncoder

class TiktokenCl100kBaseTokenEncoderTests: XCTestCase {
    func test_encoding() async throws {
        let encoder = TiktokenCl100kBaseTokenEncoder()
        let encoded = encoder.encode(text: """
        我可以吞下玻璃而不伤身体
        The quick brown fox jumps over the lazy dog
        """)
        XCTAssertEqual(encoded.count, 26)
        XCTAssertEqual(
            encoded,
            [
                37046, 74770, 7305, 252, 17297, 29207, 119, 163, 240, 225, 69636, 16937, 17885, 97,
                96356, 33014, 198, 791, 4062, 14198, 39935, 35308, 927, 279, 16053, 5679,
            ]
        )
    }
}

