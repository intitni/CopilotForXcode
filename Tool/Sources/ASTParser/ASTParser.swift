import SuggestionModel
import SwiftTreeSitter
import tree_sitter
import TreeSitterObjC
import TreeSitterSwift

public enum ParsableLanguage {
    case swift
    case objectiveC

    var tsLanguage: UnsafeMutablePointer<TSLanguage> {
        switch self {
        case .swift:
            return tree_sitter_swift()
        case .objectiveC:
            return tree_sitter_objc()
        }
    }
}

public struct ASTParser {
    let language: ParsableLanguage
    let parser: Parser

    public init(language: ParsableLanguage) {
        self.language = language
        parser = Parser()
        try! parser.setLanguage(Language(language: language.tsLanguage))
    }

    public func parse(_ source: String) -> ASTTree? {
        return ASTTree(tree: parser.parse(source))
    }
}

public typealias ASTNode = Node

public typealias ASTPoint = Point

public struct ASTTree {
    public let tree: Tree?

    public var rootNode: ASTNode? {
        return tree?.rootNode
    }

    public func smallestNodeContainingRange(
        _ range: CursorRange,
        filter: (ASTNode) -> Bool = { _ in true }
    ) -> ASTNode? {
        guard var targetNode = rootNode else { return nil }

        func rangeContains(_ range: Range<Point>, _ another: Range<Point>) -> Bool {
            return range.lowerBound <= another.lowerBound && range.upperBound >= another.upperBound
        }

        for node in targetNode.treeCursor.deepFirstSearch(skipChildren: { node in
            !rangeContains(node.pointRange, range.pointRange)
        }) {
            guard filter(node) else { continue }
            if rangeContains(node.pointRange, range.pointRange) {
                targetNode = node
            }
        }

        return targetNode
    }
}

extension CursorRange {
    var pointRange: Range<Point> {
        let bytePerCharacter = 2 // tree sitter uses UTF-16
        let startPoint = Point(row: start.line, column: start.character * bytePerCharacter)
        let endPoint = Point(row: end.line, column: end.character * bytePerCharacter)
        guard endPoint > startPoint else {
            return startPoint..<Point(
                row: start.line,
                column: (start.character + 1) * bytePerCharacter
            )
        }
        return startPoint..<endPoint
    }
}

