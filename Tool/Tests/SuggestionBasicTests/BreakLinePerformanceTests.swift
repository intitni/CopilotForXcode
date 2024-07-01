import Foundation
import XCTest
@testable import SuggestionBasic

final class BreakLinePerformanceTests: XCTestCase {
    func test_breakLines() {
        let string = String(repeating: """
        Hello
        World
        
        """, count: 50000)
        
        measure {
            let _ = string.breakLines()
        }
    }
}

