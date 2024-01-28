import Foundation
import XCTest

@testable import XcodeInspector

class SourceEditorCachePerformanceTests: XCTestCase {
    func test_source_editor_cache_get_content_comparison() {
        let content = String(repeating: """
        struct Cat: Animal {
          var name: String
        }

        """, count: 500)
        let cache = SourceEditor.Cache(sourceContent: content + "Yes")

        measure {
            for _ in 1 ... 10000 {
                _ = cache.get(content: content, selectedTextRange: nil)
            }
        }
    }
}

