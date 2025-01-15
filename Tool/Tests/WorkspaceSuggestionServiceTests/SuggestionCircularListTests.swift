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
        
        list.offsetAnchor(1)
        
        XCTAssertEqual(list.anchorIndex, 2)
        XCTAssertEqual(list.map(\.id), ["c", "d", "a", "b"])
        XCTAssertEqual(list.activeSuggestion?.id, "c")
        
        XCTAssertEqual(list[0]?.id, "c")
        XCTAssertEqual(list[1]?.id, "d")
        XCTAssertEqual(list[2]?.id, "a")
        XCTAssertEqual(list[3]?.id, "b")
        
        list.offsetAnchor(1)
        
        XCTAssertEqual(list.anchorIndex, 3)
        XCTAssertEqual(list.map(\.id), ["d", "a", "b", "c"])
        XCTAssertEqual(list.activeSuggestion?.id, "d")
        
        list.offsetAnchor(1)
        
        XCTAssertEqual(list.anchorIndex, 0)
        XCTAssertEqual(list.map(\.id), ["a", "b", "c", "d"])
        XCTAssertEqual(list.activeSuggestion?.id, "a")
        
        list.offsetAnchor(-1)
        
        XCTAssertEqual(list.anchorIndex, 3)
        XCTAssertEqual(list.map(\.id), ["d", "a", "b", "c"])
        XCTAssertEqual(list.activeSuggestion?.id, "d")
    }
}

