import ASTParser
import Foundation
import SuggestionModel
import SwiftParser
import SwiftSyntax

struct SwiftFocusedCodeFinder: FocusedCodeFinder {
    func findFocusedCode(
        containingRange: CursorRange,
        activeDocumentContext: ActiveDocumentContext
    ) -> CodeContext {
        let source = activeDocumentContext.fileContent
        let tree = Parser.parse(source: source)
        let visitor = SwiftScopeHierarchySyntaxVisitor(
            tree: tree,
            code: source,
            range: containingRange
        )
        var nodes = visitor.findScopeHierarchy()

        let code = EditorInformation.code(in: activeDocumentContext.lines, inside: containingRange)
            .code

        while let node = nodes.first {
            nodes.removeFirst()
            if var context = contextContainingNode(
                node,
                parentNodes: nodes,
                tree: tree,
                activeDocumentContext: activeDocumentContext
            ) {
                if code.isEmpty {
                    context.focusedRange = context.contextRange
                    context.focusedCode = EditorInformation.code(
                        in: activeDocumentContext.lines,
                        inside: context.contextRange
                    ).code
                } else {
                    context.focusedRange = containingRange
                    context.focusedCode = code
                }

                context.imports = visitor.imports
                return context
            }
        }
        return .init(
            scope: .file,
            contextRange: .zero,
            focusedRange: containingRange,
            focusedCode: code,
            imports: visitor.imports
        )
    }
}

extension SwiftFocusedCodeFinder {
    func contextContainingNode(
        _ node: SyntaxProtocol,
        parentNodes: [SyntaxProtocol],
        tree: SourceFileSyntax,
        activeDocumentContext: ActiveDocumentContext
    ) -> CodeContext? {
        let source = activeDocumentContext.fileContent

        func convertRange(_ node: SyntaxProtocol) -> CursorRange {
            .init(sourceRange: node.sourceRange(converter: .init(file: source, tree: tree)))
        }

        func extractText(_ node: SyntaxProtocol) -> String {
            EditorInformation.code(in: activeDocumentContext.lines, inside: convertRange(node)).code
        }

        switch node {
        case let node as StructDeclSyntax:
            let type = node.structKeyword.text
            let name = node.identifier.text
            return .init(
                scope: .scope(
                    signature: "\(type) \(name)"
                        .prefixedModifiers(node.modifierAndAttributeText(extractText))
                        .suffixedInheritance(node.inheritanceClauseTexts(extractText))
                ),
                contextRange: convertRange(node),
                focusedRange: .zero,
                focusedCode: "",
                imports: []
            )

        case let node as ClassDeclSyntax:
            let type = node.classKeyword.text
            let name = node.identifier.text
            return .init(
                scope: .scope(
                    signature: "\(type) \(name)"
                        .prefixedModifiers(node.modifierAndAttributeText(extractText))
                        .suffixedInheritance(node.inheritanceClauseTexts(extractText))
                ),
                contextRange: convertRange(node),
                focusedRange: .zero,
                focusedCode: "",
                imports: []
            )

        case let node as EnumDeclSyntax:
            let type = node.enumKeyword.text
            let name = node.identifier.text
            return .init(
                scope: .scope(
                    signature: "\(type) \(name)"
                        .prefixedModifiers(node.modifierAndAttributeText(extractText))
                        .suffixedInheritance(node.inheritanceClauseTexts(extractText))
                ),
                contextRange: convertRange(node),
                focusedRange: .zero,
                focusedCode: "",
                imports: []
            )

        case let node as ActorDeclSyntax:
            let type = node.actorKeyword.text
            let name = node.identifier.text
            return .init(
                scope: .scope(
                    signature: "\(type) \(name)"
                        .prefixedModifiers(node.modifierAndAttributeText(extractText))
                        .suffixedInheritance(node.inheritanceClauseTexts(extractText))
                ),
                contextRange: convertRange(node),
                focusedRange: .zero,
                focusedCode: "",
                imports: []
            )

        case let node as MacroDeclSyntax:
            let type = node.macroKeyword.text
            let name = node.identifier.text
            return .init(
                scope: .scope(
                    signature: "\(type) \(name)"
                        .prefixedModifiers(node.modifierAndAttributeText(extractText))
                ),
                contextRange: convertRange(node),
                focusedRange: .zero,
                focusedCode: "",
                imports: []
            )

        case let node as ProtocolDeclSyntax:
            let type = node.protocolKeyword.text
            let name = node.identifier.text
            return .init(
                scope: .scope(
                    signature: "\(type) \(name)"
                        .prefixedModifiers(node.modifierAndAttributeText(extractText))
                        .suffixedInheritance(node.inheritanceClauseTexts(extractText))
                ),
                contextRange: convertRange(node),
                focusedRange: .zero,
                focusedCode: "",
                imports: []
            )

        case let node as ExtensionDeclSyntax:
            let type = node.extensionKeyword.text
            let name = node.extendedType.trimmedDescription
            return .init(
                scope: .scope(
                    signature: "\(type) \(name)"
                        .prefixedModifiers(node.modifierAndAttributeText(extractText))
                        .suffixedInheritance(node.inheritanceClauseTexts(extractText))
                ),
                contextRange: convertRange(node),
                focusedRange: .zero,
                focusedCode: "",
                imports: []
            )

        case let node as FunctionDeclSyntax:
            let type = node.funcKeyword.text
            let name = node.identifier.text
            let signature = node.signature.trimmedDescription

            return .init(
                scope: .scope(
                    signature: "\(type) \(name)\(signature)"
                        .prefixedModifiers(node.modifierAndAttributeText(extractText))
                ),
                contextRange: convertRange(node),
                focusedRange: .zero,
                focusedCode: "",
                imports: []
            )

        case let node as VariableDeclSyntax:
            let type = node.bindingSpecifier.trimmedDescription
            let name = node.bindings.first?.pattern.trimmedDescription ?? ""
            let signature = node.bindings.first?.initializer?.value.trimmedDescription ?? ""

            return .init(
                scope: .scope(
                    signature: "\(type) \(name)\(signature)"
                        .prefixedModifiers(node.modifierAndAttributeText(extractText))
                ),
                contextRange: convertRange(node),
                focusedRange: .zero,
                focusedCode: "",
                imports: []
            )

        case let node as AccessorDeclSyntax:
            let keyword = node.accessorSpecifier.text
            var signature = keyword

            for node in parentNodes {
                if let (type, name, sig) = findAssigningToVariable(node) {
                    signature = "\(keyword) of \(type) \(name):\(sig)"
                    break
                }

                if let node = node as? SubscriptDeclSyntax {
                    let genericPClause = node.genericWhereClause?.trimmedDescription ?? ""
                    let pClause = node.parameterClause.trimmedDescription
                    let whereClause = node.genericWhereClause?.trimmedDescription ?? ""
                    signature = "\(keyword) of subscript\(genericPClause)(\(pClause))\(whereClause)"
                    break
                }
            }

            return .init(
                scope: .scope(
                    signature: signature
                        .prefixedModifiers(node.modifierAndAttributeText(extractText))
                ),
                contextRange: convertRange(node),
                focusedRange: .zero,
                focusedCode: "",
                imports: []
            )

        case let node as SubscriptDeclSyntax:
            let genericPClause = node.genericWhereClause?.trimmedDescription ?? ""
            let pClause = node.parameterClause.trimmedDescription
            let whereClause = node.genericWhereClause?.trimmedDescription ?? ""
            let signature = "subscript\(genericPClause)(\(pClause))\(whereClause)"

            return .init(
                scope: .scope(
                    signature: signature
                        .prefixedModifiers(node.modifierAndAttributeText(extractText))
                ),
                contextRange: convertRange(node),
                focusedRange: .zero,
                focusedCode: "",
                imports: []
            )

        case let node as InitializerDeclSyntax:
            var signature = "init"
            for node in parentNodes {
                if let typeName = findTypeNameFromNode(node) {
                    signature = "\(typeName).init"
                    break
                }
            }

            return .init(
                scope: .scope(
                    signature: "\(signature)"
                        .prefixedModifiers(node.modifierAndAttributeText(extractText))
                ),
                contextRange: convertRange(node),
                focusedRange: .zero,
                focusedCode: "",
                imports: []
            )

        case let node as DeinitializerDeclSyntax:
            var signature = "deinit"
            for node in parentNodes {
                if let typeName = findTypeNameFromNode(node) {
                    signature = "\(typeName).deinit"
                    break
                }
            }

            return .init(
                scope: .scope(
                    signature: signature
                        .prefixedModifiers(node.modifierAndAttributeText(extractText))
                ),
                contextRange: convertRange(node),
                focusedRange: .zero,
                focusedCode: "",
                imports: []
            )

        case let node as ClosureExprSyntax:
            var signature = "anonymous closure"

            for node in parentNodes {
                if let (type, name, sig) = findAssigningToVariable(node) {
                    signature = "closure assigned to \(type) \(name)\(sig)"
                    break
                }
            }

            return .init(
                scope: .scope(signature: signature),
                contextRange: convertRange(node),
                focusedRange: .zero,
                focusedCode: "",
                imports: []
            )

        case let node as FunctionCallExprSyntax:
            var signature = "anonymous function call"
            for node in parentNodes {
                if let (type, name, sig) = findAssigningToVariable(node) {
                    signature = "function call assigned to \(type) \(name)\(sig)"
                    break
                }
            }

            return .init(
                scope: .scope(signature: signature),
                contextRange: convertRange(node),
                focusedRange: .zero,
                focusedCode: "",
                imports: []
            )

        case let node as SwitchCaseSyntax:
            return .init(
                scope: .scope(signature: node.trimmedDescription),
                contextRange: convertRange(node),
                focusedRange: .zero,
                focusedCode: "",
                imports: []
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
            return node.identifier.text
        case let node as StructDeclSyntax:
            return node.identifier.text
        case let node as EnumDeclSyntax:
            return node.identifier.text
        case let node as ActorDeclSyntax:
            return node.identifier.text
        case let node as ProtocolDeclSyntax:
            return node.identifier.text
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
    var attributes: AttributeListSyntax? { get }
    var modifiers: ModifierListSyntax? { get }
}

extension AttributeAndModifierApplicableSyntax {
    func modifierAndAttributeText(_ extractText: (SyntaxProtocol) -> String) -> String {
        let attributeTexts = attributes?.map { attribute in
            extractText(attribute)
        } ?? []
        let modifierTexts = modifiers?.map { modifier in
            extractText(modifier)
        } ?? []
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
    var modifiers: SwiftSyntax.ModifierListSyntax? { nil }
}

extension SubscriptDeclSyntax: AttributeAndModifierApplicableSyntax {}

protocol InheritanceClauseApplicableSyntax {
    var inheritanceClause: TypeInheritanceClauseSyntax? { get }
}

extension StructDeclSyntax: InheritanceClauseApplicableSyntax {}
extension ClassDeclSyntax: InheritanceClauseApplicableSyntax {}
extension EnumDeclSyntax: InheritanceClauseApplicableSyntax {}
extension ActorDeclSyntax: InheritanceClauseApplicableSyntax {}
extension ProtocolDeclSyntax: InheritanceClauseApplicableSyntax {}
extension ExtensionDeclSyntax: InheritanceClauseApplicableSyntax {}

extension InheritanceClauseApplicableSyntax {
    func inheritanceClauseTexts(_ extractText: (SyntaxProtocol) -> String) -> String {
        inheritanceClause?.inheritedTypeCollection.map { clause in
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

// MARK: - Visitors

extension SwiftFocusedCodeFinder {
    final class SwiftScopeHierarchySyntaxVisitor: SyntaxVisitor {
        let tree: SyntaxProtocol
        let code: String
        let range: CursorRange
        var imports: [String] = []
        private var _scopeHierarchy: [SyntaxProtocol] = []

        /// The nodes containing the current range, sorted from inner to outer.
        func findScopeHierarchy(_ node: some SyntaxProtocol) -> [SyntaxProtocol] {
            walk(node)
            return _scopeHierarchy.sorted { $0.position.utf8Offset > $1.position.utf8Offset }
        }

        /// The nodes containing the current range, sorted from inner to outer.
        func findScopeHierarchy() -> [SyntaxProtocol] {
            walk(tree)
            return _scopeHierarchy.sorted { $0.position.utf8Offset > $1.position.utf8Offset }
        }

        init(tree: SyntaxProtocol, code: String, range: CursorRange) {
            self.tree = tree
            self.code = code
            self.range = range
            super.init(viewMode: .all)
        }

        func skipChildrenIfPossible(_ node: SyntaxProtocol) -> SyntaxVisitorContinueKind {
            if !nodeContainsRange(node) { return .skipChildren }
            return .visitChildren
        }

        func captureNodeIfPossible(_ node: SyntaxProtocol) -> SyntaxVisitorContinueKind {
            if !nodeContainsRange(node) { return .skipChildren }
            _scopeHierarchy.append(node)
            return .visitChildren
        }

        func nodeContainsRange(_ node: SyntaxProtocol) -> Bool {
            let sourceRange = node.sourceRange(converter: .init(file: code, tree: tree))
            let cursorRange = CursorRange(sourceRange: sourceRange)
            return cursorRange.strictlyContains(range)
        }

        // skip if possible

        override func visit(_ node: CodeBlockItemSyntax) -> SyntaxVisitorContinueKind {
            skipChildrenIfPossible(node)
        }

        override func visit(_ node: MemberDeclBlockSyntax) -> SyntaxVisitorContinueKind {
            skipChildrenIfPossible(node)
        }

        override func visit(_ node: MemberDeclListItemSyntax) -> SyntaxVisitorContinueKind {
            skipChildrenIfPossible(node)
        }

        // capture if possible

        override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
            imports.append(node.trimmedDescription)
            return .skipChildren
        }

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            captureNodeIfPossible(node)
        }

        override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
            captureNodeIfPossible(node)
        }

        override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
            captureNodeIfPossible(node)
        }

        override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
            captureNodeIfPossible(node)
        }

        override func visit(_ node: MacroDeclSyntax) -> SyntaxVisitorContinueKind {
            captureNodeIfPossible(node)
        }

        override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
            captureNodeIfPossible(node)
        }

        override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
            captureNodeIfPossible(node)
        }

        override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            captureNodeIfPossible(node)
        }

        override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
            captureNodeIfPossible(node)
        }

        override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
            captureNodeIfPossible(node)
        }

        override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
            captureNodeIfPossible(node)
        }

        override func visit(_ node: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
            captureNodeIfPossible(node)
        }

        override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
            captureNodeIfPossible(node)
        }

        override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
            captureNodeIfPossible(node)
        }

        override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            captureNodeIfPossible(node)
        }

        override func visit(_ node: SwitchCaseSyntax) -> SyntaxVisitorContinueKind {
            captureNodeIfPossible(node)
        }
    }
}

