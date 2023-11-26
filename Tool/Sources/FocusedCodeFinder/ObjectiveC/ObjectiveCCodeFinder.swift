import ASTParser
import Foundation
import Preferences
import SuggestionModel
import SwiftTreeSitter

public enum TreeSitterTextPosition {
    case node(ASTNode)
    case range(range: NSRange, pointRange: Range<Point>)
}

public class ObjectiveCFocusedCodeFinder: KnownLanguageFocusedCodeFinder<
    ASTTree,
    ASTNode,
    TreeSitterTextPosition
> {
    override public init(
        maxFocusedCodeLineCount: Int = UserDefaults.shared.value(for: \.maxFocusedCodeLineCount)
    ) {
        super.init(maxFocusedCodeLineCount: maxFocusedCodeLineCount)
    }

    public func parseSyntaxTree(from document: Document) -> ASTTree? {
        let parser = ASTParser(language: .objectiveC)
        return parser.parse(document.content)
    }

    public func collectContextNodes(
        in document: Document,
        tree: ASTTree,
        containingRange range: CursorRange,
        textProvider: @escaping TextProvider,
        rangeConverter: @escaping RangeConverter
    ) -> ContextInfo {
        let visitor = ObjectiveCScopeHierarchySyntaxVisitor(
            tree: tree,
            code: document.content,
            textProvider: { node in
                textProvider(.node(node))
            },
            range: range
        )

        let nodes = visitor.findScopeHierarchy()

        return .init(nodes: nodes, includes: visitor.includes, imports: visitor.imports)
    }

    public func createTextProviderAndRangeConverter(
        for document: Document,
        tree: ASTTree
    ) -> (TextProvider, RangeConverter) {
        (
            { position in
                switch position {
                case let .node(node):
                    return document.content.cursorTextProvider(node.range, node.pointRange) ?? ""
                case let .range(range, pointRange):
                    return document.content.cursorTextProvider(range, pointRange) ?? ""
                }
            },
            { node in
                CursorRange(pointRange: node.pointRange)
            }
        )
    }

    public func contextContainingNode(
        _ node: Node,
        textProvider: @escaping TextProvider
    ) -> NodeInfo? {
        switch ObjectiveCNodeType(rawValue: node.nodeType ?? "") {
        case .classInterface, .categoryInterface:
            return parseClassInterfaceNode(node, textProvider: textProvider)
        case .classImplementation, .categoryImplementation:
            return parseClassImplementationNode(node, textProvider: textProvider)
        case .protocolDeclaration:
            return parseProtocolNode(node, textProvider: textProvider)
        case .methodDefinition:
            return parseMethodDefinitionNode(node, textProvider: textProvider)
        case .functionDefinition:
            return parseFunctionDefinitionNode(node, textProvider: textProvider)
        case .structSpecifier, .enumSpecifier, .nsEnumSpecifier:
            return parseTypeSpecifierNode(node, textProvider: textProvider)
        case .typeDefinition:
            return parseTypedefNode(node, textProvider: textProvider)
        default:
            return nil
        }
    }

    func parseClassInterfaceNode(
        _ node: ASTNode,
        textProvider: @escaping TextProvider
    ) -> NodeInfo? {
        var name = ""
        var superClass = ""
        var category = ""
        var protocols = [String]()
        if let nameNode = node.child(byFieldName: "name") {
            name = textProvider(.node(nameNode))
        }
        if let superClassNode = node.child(byFieldName: "superclass") {
            superClass = textProvider(.node(superClassNode))
        }
        if let categoryNode = node.child(byFieldName: "category") {
            category = textProvider(.node(categoryNode))
        }
        if let protocolsNode = node.child(byFieldName: "protocols") {
            for protocolNode in protocolsNode.children {
                let protocolName = textProvider(.node(protocolNode))
                if !protocolName.isEmpty {
                    protocols.append(protocolName)
                }
            }
        }
        var signature = "@interface \(name)"
        if !category.isEmpty {
            signature += "(\(category))"
        }
        if !protocols.isEmpty {
            signature += "<\(protocols.joined(separator: ","))>"
        }
        if !superClass.isEmpty {
            signature += ": \(superClass)"
        }

        return .init(
            node: node,
            signature: signature,
            name: name,
            canBeUsedAsCodeRange: true
        )
    }

    func parseClassImplementationNode(
        _ node: ASTNode,
        textProvider: @escaping TextProvider
    ) -> NodeInfo? {
        var name = ""
        var superClass = ""
        var category = ""
        var protocols = [String]()
        if let nameNode = node.child(byFieldName: "name") {
            name = textProvider(.node(nameNode))
        }
        if let superClassNode = node.child(byFieldName: "superclass") {
            superClass = textProvider(.node(superClassNode))
        }
        if let categoryNode = node.child(byFieldName: "category") {
            category = textProvider(.node(categoryNode))
        }
        if let protocolsNode = node.child(byFieldName: "protocols") {
            for protocolNode in protocolsNode.children {
                let protocolName = textProvider(.node(protocolNode))
                if !protocolName.isEmpty {
                    protocols.append(protocolName)
                }
            }
        }

        var signature = "@implementation \(name)"
        if !category.isEmpty {
            signature += "(\(category))"
        }
        if !protocols.isEmpty {
            signature += "<\(protocols.joined(separator: ","))>"
        }
        if !superClass.isEmpty {
            signature += ": \(superClass)"
        }
        return .init(
            node: node,
            signature: signature,
            name: name,
            canBeUsedAsCodeRange: true
        )
    }

    func parseProtocolNode(
        _ node: ASTNode,
        textProvider: @escaping TextProvider
    ) -> NodeInfo? {
        var name = ""
        var protocols = [String]()
        if let nameNode = node.child(byFieldName: "name") {
            name = textProvider(.node(nameNode))
        }
        if let protocolsNode = node.child(byFieldName: "protocols") {
            for protocolNode in protocolsNode.children {
                let protocolName = textProvider(.node(protocolNode))
                if !protocolName.isEmpty {
                    protocols.append(protocolName)
                }
            }
        }

        var signature = "@protocol \(name)"
        if !protocols.isEmpty {
            signature += "<\(protocols.joined(separator: ","))>"
        }
        return .init(
            node: node,
            signature: signature,
            name: name,
            canBeUsedAsCodeRange: true
        )
    }

    func parseMethodDefinitionNode(
        _ node: ASTNode,
        textProvider: @escaping TextProvider
    ) -> NodeInfo? {
        parseSignatureBeforeBody(node, fieldNameForName: "selector", textProvider: textProvider)
    }

    func parseTypeSpecifierNode(
        _ node: ASTNode,
        textProvider: @escaping TextProvider
    ) -> NodeInfo? {
        parseSignatureBeforeBody(node, textProvider: textProvider)
    }

    func parseTypedefNode(
        _ node: ASTNode,
        textProvider: @escaping TextProvider
    ) -> NodeInfo? {
        guard let typeNode = node.child(byFieldName: "type") else { return nil }
        return parseSignatureBeforeBody(typeNode, textProvider: textProvider)
    }

    func parseFunctionDefinitionNode(
        _ node: ASTNode,
        textProvider: @escaping TextProvider
    ) -> NodeInfo? {
        let declaratorNode = node.child(byFieldName: "declarator")
        let name = declaratorNode?.contentOfChild(
            withFieldName: "declarator",
            textProvider: textProvider
        )
        let (
            _,
            signatureRange,
            signaturePointRange
        ) = node.extractInformationBeforeNode(withFieldName: "body")
        let signature = textProvider(.range(range: signatureRange, pointRange: signaturePointRange))
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if signature.isEmpty { return nil }
        return .init(
            node: node,
            signature: signature,
            name: name ?? "N/A",
            canBeUsedAsCodeRange: false
        )
    }
}

// MARK: - Shared Parser

extension ObjectiveCFocusedCodeFinder {
    func parseSignatureBeforeBody(
        _ node: ASTNode,
        fieldNameForName: String = "name",
        textProvider: @escaping TextProvider
    ) -> NodeInfo? {
        let name = node.contentOfChild(withFieldName: fieldNameForName, textProvider: textProvider)
        let (
            _,
            signatureRange,
            signaturePointRange
        ) = node.extractInformationBeforeNode(withFieldName: "body")
        let signature = textProvider(.range(range: signatureRange, pointRange: signaturePointRange))
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if signature.isEmpty { return nil }
        return .init(
            node: node,
            signature: signature,
            name: name ?? "N/A",
            canBeUsedAsCodeRange: false
        )
    }
}

extension ASTNode {
    func contentOfChild(
        withFieldName name: String,
        textProvider: (TreeSitterTextPosition) -> String
    ) -> String? {
        guard let child = child(byFieldName: name) else { return nil }
        return textProvider(.node(child))
    }

    func extractInformationBeforeNode(withFieldName name: String) -> (
        postfixNode: ASTNode?,
        range: NSRange,
        pointRange: Range<Point>
    ) {
        guard let postfixNode = child(byFieldName: name) else {
            return (nil, range, pointRange)
        }

        let range = self.range.subtracting(postfixNode.range)
        let pointRange = self.pointRange.subtracting(postfixNode.pointRange)
        return (postfixNode, range, pointRange)
    }
}

extension NSRange {
    func subtracting(_ range: NSRange) -> NSRange {
        let start = lowerBound
        let end = Swift.max(lowerBound, Swift.min(upperBound, range.lowerBound))
        return NSRange(location: start, length: end - start)
    }
}

extension Range where Bound == Point {
    func subtracting(_ range: Range<Bound>) -> Range<Bound> {
        let start = lowerBound
        let end = if range.lowerBound >= upperBound {
            upperBound
        } else {
            Swift.max(range.lowerBound, lowerBound)
        }
        return Range(uncheckedBounds: (start, end))
    }
}

