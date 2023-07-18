import Foundation
import XCTest

@testable import ASTParser

class CursorDeepFirstSearchTests: XCTestCase {
    class TN {
        var parent: TN?
        var value: Int
        var children: [TN] = []
        
        init(_ value: Int, _ children: [TN] = []) {
            self.value = value
            self.children = children
            children.forEach { $0.parent = self }
        }
    }
    
    class ACursor: Cursor {
        var currentNode: TN?
        init(currentNode: TN?) {
            self.currentNode = currentNode
        }
        
        func goToFirstChild() -> Bool {
            if let first = currentNode?.children.first {
                currentNode = first
                return true
            }
            return false
        }
        
        func goToNextSibling() -> Bool {
            if let parent = currentNode?.parent,
               let index = parent.children.firstIndex(where: { $0 === currentNode }),
               index < parent.children.count - 1 {
                currentNode = parent.children[index + 1]
                return true
            }
            return false
        }
        
        func goToParent() -> Bool {
            if let parent = currentNode?.parent {
                currentNode = parent
                return true
            }
            return false
        }
    }
    
    func test_deep_first_search() {
        let root = TN(0, [
            TN(1, [
                TN(2),
                TN(3)
            ]),
            TN(4, [
                TN(5, [TN(6, [TN(7)])]),
                TN(8)
            ])
        ])
        let cursor = ACursor(currentNode: root)
        var result = [Int]()
        for node in CursorDeepFirstSearchSequence(cursor: cursor, skipChildren: { _ in true }) {
            result.append(node.value)
        }
        
        XCTAssertEqual(result, result.sorted())
    }
    
    func test_deep_first_search_skip_children() {
        let root = TN(0, [
            TN(1, [
                TN(2),
                TN(3)
            ]),
            TN(4, [
                TN(5, [TN(6, [TN(7)])]),
                TN(8)
            ])
        ])
        let cursor = ACursor(currentNode: root)
        var result = [Int]()
        for node in CursorDeepFirstSearchSequence(cursor: cursor, skipChildren: { $0.value == 5 }) {
            result.append(node.value)
        }
        
        XCTAssertEqual(result, [0, 1, 2, 3, 4, 5, 8])
    }
}
