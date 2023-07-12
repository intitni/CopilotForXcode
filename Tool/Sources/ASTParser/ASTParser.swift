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

public struct ASTTree {
    public let tree: Tree?

    public var rootNode: Node? {
        return tree?.rootNode
    }
}

