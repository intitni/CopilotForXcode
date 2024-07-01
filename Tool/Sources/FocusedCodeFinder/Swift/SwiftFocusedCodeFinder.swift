import ASTParser
import Foundation
import Preferences
import SuggestionBasic
import SwiftParser
import SwiftSyntax

public class SwiftFocusedCodeFinder: KnownLanguageFocusedCodeFinder<
    SourceFileSyntax,
    SyntaxProtocol,
    SyntaxProtocol
> {
    override public init(maxFocusedCodeLineCount: Int) {
        super.init(maxFocusedCodeLineCount: maxFocusedCodeLineCount)
    }

    public func parseSyntaxTree(from document: Document) -> SourceFileSyntax? {
        Parser.parse(source: document.content)
    }

    public func collectContextNodes(
        in document: Document,
        tree: SourceFileSyntax,
        containingRange range: CursorRange,
        textProvider: @escaping TextProvider,
        rangeConverter: @escaping RangeConverter
    ) -> ContextInfo {
        let visitor = SwiftScopeHierarchySyntaxVisitor(
            tree: tree,
            code: document.content,
            range: range,
            rangeConverter: rangeConverter
        )

        let nodes = visitor.findScopeHierarchy()
        return .init(
            nodes: nodes,
            includes: [],
            imports: visitor.imports
        )
    }

    public func createTextProviderAndRangeConverter(
        for document: Document,
        tree: SourceFileSyntax
    ) -> (TextProvider, RangeConverter) {
        let locationConverter = SourceLocationConverter(
            fileName: document.documentURL.path,
            tree: tree
        )
        return (
            { node in
                let range = CursorRange(sourceRange: node.sourceRange(converter: locationConverter))
                return EditorInformation.code(in: document.lines, inside: range).code
            },
            { node in
                let range = CursorRange(sourceRange: node.sourceRange(converter: locationConverter))
                return range
            }
        )
    }

    public func contextContainingNode(
        _ node: SyntaxProtocol,
        textProvider: @escaping TextProvider,
        rangeConverter: @escaping RangeConverter
    ) -> NodeInfo? {
        func extractText(_ node: SyntaxProtocol) -> String {
            textProvider(node)
        }

        switch node {
        case let node as StructDeclSyntax:
            let type = node.structKeyword.text
            let name = node.name.text
            return .init(
                node: node,
                signature: "\(type) \(name)"
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .suffixedInheritance(node.inheritanceClauseTexts(extractText))
                    .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                    .joined(separator: " "),
                name: name
            )

        case let node as ClassDeclSyntax:
            let type = node.classKeyword.text
            let name = node.name.text
            return .init(
                node: node,
                signature: "\(type) \(name)"
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .suffixedInheritance(node.inheritanceClauseTexts(extractText))
                    .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                    .joined(separator: " "),
                name: name
            )

        case let node as EnumDeclSyntax:
            let type = node.enumKeyword.text
            let name = node.name.text
            return .init(
                node: node,
                signature: "\(type) \(name)"
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .suffixedInheritance(node.inheritanceClauseTexts(extractText))
                    .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                    .joined(separator: " "),
                name: name
            )

        case let node as ActorDeclSyntax:
            let type = node.actorKeyword.text
            let name = node.name.text
            return .init(
                node: node,
                signature: "\(type) \(name)"
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .suffixedInheritance(node.inheritanceClauseTexts(extractText))
                    .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                    .joined(separator: " "),
                name: name
            )

        case let node as MacroDeclSyntax:
            let type = node.macroKeyword.text
            let name = node.name.text
            return .init(
                node: node,
                signature: "\(type) \(name)"
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                    .joined(separator: " "),
                name: name
            )

        case let node as ProtocolDeclSyntax:
            let type = node.protocolKeyword.text
            let name = node.name.text
            return .init(
                node: node,
                signature: "\(type) \(name)"
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .suffixedInheritance(node.inheritanceClauseTexts(extractText))
                    .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                    .joined(separator: " "),
                name: name
            )

        case let node as ExtensionDeclSyntax:
            let type = node.extensionKeyword.text
            let name = node.extendedType.trimmedDescription
            return .init(
                node: node,
                signature: "\(type) \(name)"
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .suffixedInheritance(node.inheritanceClauseTexts(extractText))
                    .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                    .joined(separator: " "),
                name: name
            )

        case let node as FunctionDeclSyntax:
            let type = node.funcKeyword.text
            let name = node.name.text
            let signature = node.signature.trimmedDescription
                .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .joined(separator: " ")

            return .init(
                node: node,
                signature: "\(type) \(name)\(signature)"
                    .prefixedModifiers(node.modifierAndAttributeText(extractText)),
                name: name
            )

        case let node as VariableDeclSyntax:
            let type = node.bindingSpecifier.trimmedDescription
            let name = node.bindings.first?.pattern.trimmedDescription ?? ""
            let signature = node.bindings.first?.typeAnnotation?.trimmedDescription ?? ""

            return .init(
                node: node,
                signature: "\(type) \(name)\(signature.isEmpty ? "" : "\(signature)")"
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                    .joined(separator: " "),
                name: name,
                canBeUsedAsCodeRange: node.bindings.first?.accessorBlock != nil
            )

        case let node as AccessorDeclSyntax:
            let keyword = node.accessorSpecifier.text
            let signature = keyword

            return .init(
                node: node,
                signature: signature
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                    .joined(separator: " "),
                name: keyword
            )

        case let node as SubscriptDeclSyntax:
            let genericPClause = node.genericWhereClause?.trimmedDescription ?? ""
            let pClause = node.parameterClause.trimmedDescription
            let whereClause = node.genericWhereClause?.trimmedDescription ?? ""
            let signature = "subscript\(genericPClause)(\(pClause))\(whereClause)"

            return .init(
                node: node,
                signature: signature
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                    .joined(separator: " "),
                name: "subscript"
            )

        case let node as InitializerDeclSyntax:
            let signature = "init"

            return .init(
                node: node,
                signature: "\(signature)"
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                    .joined(separator: " "),
                name: "init"
            )

        case let node as DeinitializerDeclSyntax:
            let signature = "deinit"

            return .init(
                node: node,
                signature: signature
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                    .joined(separator: " "),
                name: "deinit"
            )

        case let node as ClosureExprSyntax:
            let signature = "closure"
            let range = rangeConverter(node)

            return .init(
                node: node,
                signature: signature
                    .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                    .joined(separator: " "),
                name: "closure",
                canBeUsedAsCodeRange: range.lineCount > 80
            )

        case let node as FunctionCallExprSyntax:
            let signature = "function call"
            return .init(
                node: node,
                signature: signature
                    .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                    .joined(separator: " "),
                name: "function call",
                canBeUsedAsCodeRange: false
            )

        case let node as SwitchCaseSyntax:
            let range = rangeConverter(node)
            
            return .init(
                node: node,
                signature: node.trimmedDescription
                    .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                    .joined(separator: " "),
                name: "switch",
                canBeUsedAsCodeRange: range.lineCount > 80
            )

        default:
            return nil
        }
    }

    func findAssigningToVariable(_ node: SyntaxProtocol)
        -> (type: String, name: String, signature: String)?
    {
        if let node = node as? VariableDeclSyntax {
            let type = node.bindingSpecifier.trimmedDescription
            let name = node.bindings.first?.pattern.trimmedDescription ?? ""
            let sig = node.bindings.first?.initializer?.value.trimmedDescription ?? ""
            return (type, name, sig)
        }
        return nil
    }

    func findTypeNameFromNode(_ node: SyntaxProtocol) -> String? {
        switch node {
        case let node as ClassDeclSyntax:
            return node.name.text
        case let node as StructDeclSyntax:
            return node.name.text
        case let node as EnumDeclSyntax:
            return node.name.text
        case let node as ActorDeclSyntax:
            return node.name.text
        case let node as ProtocolDeclSyntax:
            return node.name.text
        case let node as ExtensionDeclSyntax:
            return node.extendedType.trimmedDescription
        default:
            return nil
        }
    }
}

extension CursorRange {
    init(sourceRange: SourceRange) {
        self.init(
            start: .init(line: sourceRange.start.line - 1, character: sourceRange.start.column - 1),
            end: .init(line: sourceRange.end.line - 1, character: sourceRange.end.column - 1)
        )
    }
}

// MARK: - Helper Types

protocol AttributeAndModifierApplicableSyntax {
    var attributes: AttributeListSyntax { get }
    var modifiers: DeclModifierListSyntax { get }
}

extension AttributeAndModifierApplicableSyntax {
    func modifierAndAttributeText(_ extractText: (SyntaxProtocol) -> String) -> String {
        let attributeTexts = attributes.map { attribute in
            extractText(attribute)
        }
        let modifierTexts = modifiers.map { modifier in
            extractText(modifier)
        }
        let prefix = (attributeTexts + modifierTexts).joined(separator: " ")
        return prefix
    }
}

extension StructDeclSyntax: AttributeAndModifierApplicableSyntax {}
extension ClassDeclSyntax: AttributeAndModifierApplicableSyntax {}
extension EnumDeclSyntax: AttributeAndModifierApplicableSyntax {}
extension ActorDeclSyntax: AttributeAndModifierApplicableSyntax {}
extension MacroDeclSyntax: AttributeAndModifierApplicableSyntax {}
extension MacroExpansionDeclSyntax: AttributeAndModifierApplicableSyntax {}
extension ProtocolDeclSyntax: AttributeAndModifierApplicableSyntax {}
extension ExtensionDeclSyntax: AttributeAndModifierApplicableSyntax {}
extension FunctionDeclSyntax: AttributeAndModifierApplicableSyntax {}
extension VariableDeclSyntax: AttributeAndModifierApplicableSyntax {}
extension InitializerDeclSyntax: AttributeAndModifierApplicableSyntax {}
extension DeinitializerDeclSyntax: AttributeAndModifierApplicableSyntax {}
extension AccessorDeclSyntax: AttributeAndModifierApplicableSyntax {
    var modifiers: SwiftSyntax.DeclModifierListSyntax { [] }
}

extension SubscriptDeclSyntax: AttributeAndModifierApplicableSyntax {}

protocol InheritanceClauseApplicableSyntax {
    var inheritanceClause: InheritanceClauseSyntax? { get }
}

extension StructDeclSyntax: InheritanceClauseApplicableSyntax {}
extension ClassDeclSyntax: InheritanceClauseApplicableSyntax {}
extension EnumDeclSyntax: InheritanceClauseApplicableSyntax {}
extension ActorDeclSyntax: InheritanceClauseApplicableSyntax {}
extension ProtocolDeclSyntax: InheritanceClauseApplicableSyntax {}
extension ExtensionDeclSyntax: InheritanceClauseApplicableSyntax {}

extension InheritanceClauseApplicableSyntax {
    func inheritanceClauseTexts(_ extractText: (SyntaxProtocol) -> String) -> String {
        inheritanceClause?.inheritedTypes.map { clause in
            extractText(clause).trimmingCharacters(in: [","])
        }.joined(separator: ", ") ?? ""
    }
}

extension String {
    func prefixedModifiers(_ text: String) -> String {
        if text.isEmpty {
            return self
        }
        return "\(text) \(self)"
    }

    func suffixedInheritance(_ text: String) -> String {
        if text.isEmpty {
            return self
        }
        return "\(self): \(text)"
    }
}

