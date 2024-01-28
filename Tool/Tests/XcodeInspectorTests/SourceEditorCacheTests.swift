import Foundation
import XCTest

@testable import XcodeInspector

class SourceEditorCacheTests: XCTestCase {
    func test_source_editor_cache_get_content_thread_safe() {
        func randomContent() -> String {
            String(repeating: """
            struct Cat: Animal {
              var name: String
            }

            """, count: Int.random(in: 2...10))
        }

        func randomSelectionRange() -> ClosedRange<Int> {
            let random = Int.random(in: 0...20)
            return random...random
        }

        let cache = SourceEditor.Cache()

        let max = 5000
        let exp = expectation(description: "test_source_editor_cache_get_content_thread_safe")
        DispatchQueue.concurrentPerform(iterations: max) { count in
            let content = randomContent()
            let selectionRange = randomSelectionRange()
            let result = cache.get(content: content, selectedTextRange: selectionRange)

            XCTAssertEqual(result.lines, content.breakLines(appendLineBreakToLastLine: false))
            XCTAssertEqual(result.selections, [SourceEditor.convertRangeToCursorRange(
                selectionRange,
                in: result.lines
            )])
            
            if max == count + 1 {
                exp.fulfill()
            }
        }
        
        wait(for: [exp], timeout: 10)
    }
}

