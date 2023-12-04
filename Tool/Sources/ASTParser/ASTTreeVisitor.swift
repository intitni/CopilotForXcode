import Foundation
import SwiftTreeSitter

public enum ASTTreeVisitorContinueKind {
    /// The visitor should visit the descendants of the current node.
    case visitChildren
    /// The visitor should avoid visiting the descendants of the current node.
    case skipChildren
}

// A SwiftSyntax style tree visitor.
open class ASTTreeVisitor {
    public let tree: ASTTree

    public init(tree: ASTTree) {
        self.tree = tree
    }

    public func walk() {
        guard let cursor = tree.rootNode?.treeCursor else { return }
        visit(cursor)
    }
    
    public func walk(_ node: ASTNode) {
        let cursor = node.treeCursor
        visit(cursor)
    }

    open func visit(_: ASTNode) -> ASTTreeVisitorContinueKind {
        // do nothing
        return .skipChildren
    }

    open func visitPost(_: ASTNode) {
        // do nothing
    }

    private func visit(_ cursor: TreeCursor) {
        guard let currentNode = cursor.currentNode else { return }
        let continueKind = visit(currentNode)

        switch continueKind {
        case .skipChildren:
            visitPost(currentNode)
        case .visitChildren:
            visitChildren(cursor)
            visitPost(currentNode)
        }
    }

    private func visitChildren(_ cursor: TreeCursor) {
        let hasChild = cursor.goToFirstChild()
        guard hasChild else { return }
        visit(cursor)
        while cursor.goToNextSibling() {
            visit(cursor)
        }
        _ = cursor.gotoParent()
    }
}

