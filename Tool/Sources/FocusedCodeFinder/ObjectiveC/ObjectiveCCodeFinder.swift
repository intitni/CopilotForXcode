import ASTParser
import Foundation
import Preferences
import SuggestionBasic
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
    override public init(maxFocusedCodeLineCount: Int) {
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
        textProvider: @escaping TextProvider,
        rangeConverter: @escaping RangeConverter
    ) -> NodeInfo? {
        switch ObjectiveCNodeType(rawValue: node.nodeType ?? "") {
        case .classInterface, .categoryInterface:
            return parseDeclarationInterfaceNode(node, textProvider: textProvider)
        case .classImplementation, .categoryImplementation:
            return parseDeclarationInterfaceNode(node, textProvider: textProvider)
        case .protocolDeclaration:
            return parseDeclarationInterfaceNode(node, textProvider: textProvider)
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

    func parseDeclarationInterfaceNode(
        _ node: ASTNode,
        textProvider: @escaping TextProvider
    ) -> NodeInfo? {
        var name = ""
        var category = ""
        /// Attributes, declaration kind, and name.
        var prefix = ""
        /// Generics, super class, etc.
        var extra = ""

        if let nameNode = node.child(byFieldName: "name") {
            name = textProvider(.node(nameNode))
            prefix = textProvider(.range(
                range: node.range.notSurpassing(nameNode.range),
                pointRange: node.pointRange.notSurpassing(nameNode.pointRange)
            ))
        }
        if let categoryNode = node.child(byFieldName: "category") {
            category = textProvider(.node(categoryNode))
        }

        for i in 0..<node.childCount {
            guard let childNode = node.child(at: i) else { continue }
            switch ObjectiveCNodeType(rawValue: childNode.nodeType) {
            case .superclassReference,
                 .protocolQualifiers,
                 .parameterizedClassTypeArguments:
                extra.append(textProvider(.node(childNode)))
            case .genericsTypeReference:
                // When it's a category of a generic type, e.g.
                // @interface __GENERICS(NSArray, ObjectType) (BlocksKit)
                if let nameNode = childNode.child(byFieldName: "name") {
                    name = textProvider(.node(nameNode))
                }
                prefix = textProvider(.range(
                    range: node.range.notSurpassing(childNode.range),
                    pointRange: node.pointRange.notSurpassing(childNode.pointRange)
                ))
            default: continue
            }
        }

        prefix = prefix.split(whereSeparator: \.isNewline)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        extra = extra.split(whereSeparator: \.isNewline)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var signature = "\(prefix)\(extra)"
        if !category.isEmpty {
            signature += " (\(category))"
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
        guard var result = parseSignatureBeforeBody(typeNode, textProvider: textProvider)
        else { return nil }
        result.signature = "typedef \(result.signature)"
        result.node = node
        return result
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
            .breakLines(proposedLineEnding: " ", appendLineBreakToLastLine: false)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if signature.isEmpty { return nil }
        return .init(
            node: node,
            signature: signature,
            name: name ?? "N/A",
            canBeUsedAsCodeRange: true
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
            .breakLines(proposedLineEnding: " ", appendLineBreakToLastLine: false)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if signature.isEmpty { return nil }
        return .init(
            node: node,
            signature: signature,
            name: name ?? "N/A",
            canBeUsedAsCodeRange: true
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

    func notSurpassing(_ range: NSRange) -> NSRange {
        let start = lowerBound
        let end = Swift.max(lowerBound, Swift.min(upperBound, range.upperBound))
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

    func notSurpassing(_ range: Range<Bound>) -> Range<Bound> {
        let start = lowerBound
        let end = if range.lowerBound >= upperBound {
            upperBound
        } else {
            Swift.max(range.upperBound, lowerBound)
        }
        return Range(uncheckedBounds: (start, end))
    }
}

