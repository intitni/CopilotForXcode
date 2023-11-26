import ASTParser
import Foundation
import Preferences
import SuggestionModel
import SwiftTreeSitter

final class ObjectiveCScopeHierarchySyntaxVisitor: ASTTreeVisitor {
    let range: CursorRange
    let code: String
    let textProvider: (ASTNode) -> String
    var includes: [String] = []
    var imports: [String] = []
    private var _scopeHierarchy: [ASTNode] = []

    init(
        tree: ASTTree,
        code: String,
        textProvider: @escaping (ASTNode) -> String,
        range: CursorRange
    ) {
        self.range = range
        self.code = code
        self.textProvider = textProvider
        super.init(tree: tree)
    }
    
    /// The nodes containing the current range, sorted from inner to outer.
    func findScopeHierarchy(_ node: ASTNode) -> [ASTNode] {
        walk(node)
        return _scopeHierarchy.sorted { $0.range.location > $1.range.location }
    }
    
    /// The nodes containing the current range, sorted from inner to outer.
    func findScopeHierarchy() -> [ASTNode] {
        walk()
        return _scopeHierarchy.sorted { $0.range.location > $1.range.location }
    }

    override func visit(_ node: ASTNode) -> ASTTreeVisitorContinueKind {
        let cursorRange = CursorRange(pointRange: node.pointRange)

        switch ObjectiveCNodeType(rawValue: node.nodeType ?? "") {
        case .translationUnit:
            return .visitChildren
        case .preprocInclude:
            handlePreprocInclude(node)
            return .skipChildren
        case .preprocImport:
            handlePreprocImport(node)
            return .skipChildren
        case .moduleImport:
            handleModuleImport(node)
            return .skipChildren
        case .classInterface, .categoryInterface, .protocolDeclaration:
            guard cursorRange.contains(range) else { return .skipChildren }
            _scopeHierarchy.append(node)
            return .visitChildren
        case .classImplementation, .categoryImplementation:
            guard cursorRange.contains(range) else { return .skipChildren }
            _scopeHierarchy.append(node)
            return .visitChildren
        case .methodDefinition:
            guard cursorRange.contains(range) else { return .skipChildren }
            _scopeHierarchy.append(node)
            return .skipChildren
        case .typeDefinition:
            guard cursorRange.contains(range) else { return .skipChildren }
            _scopeHierarchy.append(node)
            return .skipChildren
        case .structSpecifier, .enumSpecifier, .nsEnumSpecifier:
            guard cursorRange.contains(range) else { return .skipChildren }
            _scopeHierarchy.append(node)
            return .skipChildren 
        case .functionDefinition:
            guard cursorRange.contains(range) else { return .skipChildren }
            _scopeHierarchy.append(node)
            return .skipChildren
        default:
            return .skipChildren
        }
    }

    override func visitPost(_: ASTNode) {}

    // MARK: Imports

    func handlePreprocInclude(_ node: ASTNode) {
        let children = node.children
        for child in children {
            if let pathNode = child.child(byFieldName: "path") {
                let path = textProvider(pathNode)
                if !path.isEmpty {
                    includes.append(path.replacingOccurrences(of: "\"", with: ""))
                }
                break
            }
        }
    }

    func handlePreprocImport(_ node: ASTNode) {
        let children = node.children
        for child in children {
            if let pathNode = child.child(byFieldName: "path") {
                let path = textProvider(pathNode)
                if !path.isEmpty {
                    imports.append(
                        path
                            .replacingOccurrences(of: "\"", with: "")
                            .replacingOccurrences(of: "<", with: "")
                            .replacingOccurrences(of: ">", with: "")
                    )
                }
                break
            }
        }
    }

    func handleModuleImport(_ node: ASTNode) {
        let children = node.children
        for child in children {
            if let pathNode = child.child(byFieldName: "module") {
                let path = textProvider(pathNode)
                if !path.isEmpty {
                    imports.append(path)
                }
                break
            }
        }
    }
}

