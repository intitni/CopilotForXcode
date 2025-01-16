import Foundation
import XCTest

@testable import WorkspaceSuggestionService

class SuggestionCircularListTests: XCTestCase {
    func test_circular_list_offset_anchor() {
        var list = FileSuggestionManager.CircularSuggestionList()
        list.suggestions = [
            .group(.init(
                source: "a",
                suggestions: [.init(id: "a", text: "a", position: .zero, range: .zero)]
            )),
            .group(.init(
                source: "b",
                suggestions: [.init(id: "b", text: "b", position: .zero, range: .zero)]
            )),
            .group(.init(
                source: "c",
                suggestions: [.init(id: "c", text: "c", position: .zero, range: .zero)]
            )),
            .group(.init(
                source: "d",
                suggestions: [.init(id: "d", text: "d", position: .zero, range: .zero)]
            )),
        ]
        
        XCTAssertEqual(list.anchorIndex, 0)
        XCTAssertEqual(list.map(\.id), ["a", "b", "c", "d"])
        XCTAssertEqual(list.activeSuggestion?.id, "a")
        
        XCTAssertEqual(list[0]?.id, "a")
        XCTAssertEqual(list[1]?.id, "b")
        XCTAssertEqual(list[2]?.id, "c")
        XCTAssertEqual(list[3]?.id, "d")
        
        list.offsetAnchor(1)
        
        XCTAssertEqual(list.anchorIndex, 1)
        XCTAssertEqual(list.map(\.id), ["b", "c", "d", "a"])
        XCTAssertEqual(list.activeSuggestion?.id, "b")
        XCTAssertEqual(list.indices, 0..<4)
        
        list.offsetAnchor(1)
        
        XCTAssertEqual(list.anchorIndex, 2)
        XCTAssertEqual(list.map(\.id), ["c", "d", "a", "b"])
        XCTAssertEqual(list.activeSuggestion?.id, "c")
        XCTAssertEqual(list.indices, 0..<4)
        
        XCTAssertEqual(list[0]?.id, "c")
        XCTAssertEqual(list[1]?.id, "d")
        XCTAssertEqual(list[2]?.id, "a")
        XCTAssertEqual(list[3]?.id, "b")
        
        list.offsetAnchor(1)
        
        XCTAssertEqual(list.anchorIndex, 3)
        XCTAssertEqual(list.map(\.id), ["d", "a", "b", "c"])
        XCTAssertEqual(list.activeSuggestion?.id, "d")
        XCTAssertEqual(list.indices, 0..<4)
        
        list.offsetAnchor(1)
        
        XCTAssertEqual(list.anchorIndex, 0)
        XCTAssertEqual(list.map(\.id), ["a", "b", "c", "d"])
        XCTAssertEqual(list.activeSuggestion?.id, "a")
        XCTAssertEqual(list.indices, 0..<4)
        
        list.offsetAnchor(-1)
        
        XCTAssertEqual(list.anchorIndex, 3)
        XCTAssertEqual(list.map(\.id), ["d", "a", "b", "c"])
        XCTAssertEqual(list.activeSuggestion?.id, "d")
        XCTAssertEqual(list.indices, 0..<4)
    }
    
    func test_actual_index_computation() {
        let f =  FileSuggestionManager.CircularSuggestionList.actualIndex(of:anchorIndex:count:)
        XCTAssertEqual(f(0, 0, 0), 0)
        XCTAssertEqual(f(0, 0, 1), 0)
        XCTAssertEqual(f(0, 1, 1), 0)
        XCTAssertEqual(f(0, 0, 2), 0)
        XCTAssertEqual(f(0, 1, 2), 1)
        XCTAssertEqual(f(1, 0, 2), 1)
        XCTAssertEqual(f(1, 1, 2), 0)
        XCTAssertEqual(f(0, 0, 5), 0)
        XCTAssertEqual(f(0, 1, 5), 1)
        XCTAssertEqual(f(0, 2, 5), 2)
        XCTAssertEqual(f(0, 3, 5), 3)
        XCTAssertEqual(f(0, 4, 5), 4)
        XCTAssertEqual(f(1, 0, 5), 1)
        XCTAssertEqual(f(2, 0, 5), 2)
        XCTAssertEqual(f(3, 0, 5), 3)
        XCTAssertEqual(f(4, 0, 5), 4)
        XCTAssertEqual(f(2, 1, 5), 3)
        XCTAssertEqual(f(2, 2, 5), 4)
        XCTAssertEqual(f(2, 3, 5), 0)
        XCTAssertEqual(f(2, 4, 5), 1)
    }
}

