import Foundation
import SwiftTreeSitter

extension TreeCursor {
    /// Deep first search nodes.
    /// - Parameter skipChildren: Check if children of a `Node` should be skipped.
    func deepFirstSearch(
        skipChildren: @escaping (Node) -> Bool
    ) -> CursorDeepFirstSearchSequence<TreeCursor> {
        return CursorDeepFirstSearchSequence(cursor: self, skipChildren: skipChildren)
    }
}

// MARK: - Search

protocol Cursor {
    associatedtype Node
    var currentNode: Node? { get }
    func goToFirstChild() -> Bool
    func goToNextSibling() -> Bool
    func goToParent() -> Bool
}

extension TreeCursor: Cursor {
    func goToNextSibling() -> Bool {
        gotoNextSibling()
    }
    
    func goToParent() -> Bool {
        gotoParent()
    }
}

struct CursorDeepFirstSearchSequence<C: Cursor>: Sequence {
    let cursor: C
    let skipChildren: (C.Node) -> Bool

    func makeIterator() -> CursorDeepFirstSearchIterator<C> {
        return CursorDeepFirstSearchIterator(
            cursor: cursor,
            skipChildren: skipChildren
        )
    }

    struct CursorDeepFirstSearchIterator<C: Cursor>: IteratorProtocol {
        let cursor: C
        let skipChildren: (C.Node) -> Bool
        var isEnded = false

        mutating func next() -> C.Node? {
            guard !isEnded else { return nil }
            let currentNode = cursor.currentNode
            let hasChild = {
                guard let n = currentNode else { return false }
                if skipChildren(n) { return false }
                return cursor.goToFirstChild()
            }()
            if !hasChild {
                while !cursor.goToNextSibling() {
                    if !cursor.goToParent() {
                        isEnded = true
                        break
                    }
                }
            }

            return currentNode
        }
    }
}

