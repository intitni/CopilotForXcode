import ASTParser
import Foundation
import Preferences
import SuggestionModel
import SwiftParser
import SwiftSyntax

public struct SwiftFocusedCodeFinder: FocusedCodeFinderType {
    public let maxFocusedCodeLineCount: Int

    public init(
        maxFocusedCodeLineCount: Int = UserDefaults.shared
            .value(for: \.maxFocusedCodeLineCount)
    ) {
        self.maxFocusedCodeLineCount = maxFocusedCodeLineCount
    }

    public func findFocusedCode(
        containingRange range: CursorRange,
        activeDocumentContext: ActiveDocumentContext
    ) -> CodeContext {
        let source = activeDocumentContext.fileContent
        #warning("TODO: cache the tree")
        let tree = Parser.parse(source: source)

        let locationConverter = SourceLocationConverter(
            file: activeDocumentContext.filePath,
            tree: tree
        )

        let visitor = SwiftScopeHierarchySyntaxVisitor(
            tree: tree,
            code: source,
            range: range,
            locationConverter: locationConverter
        )

        var nodes = visitor.findScopeHierarchy()

        var codeRange: CursorRange

        func convertRange(_ node: SyntaxProtocol) -> CursorRange {
            .init(sourceRange: node.sourceRange(converter: locationConverter))
        }

        if range.isEmpty {
            // use the first scope as code, the second as context
            var focusedNode: SyntaxProtocol?
            while let node = nodes.first {
                nodes.removeFirst()
                let (context, _) = contextContainingNode(
                    node,
                    parentNodes: nodes,
                    tree: tree,
                    activeDocumentContext: activeDocumentContext,
                    locationConverter: locationConverter
                )
                if context?.canBeUsedAsCodeRange ?? false {
                    focusedNode = node
                    break
                }
            }
            guard let focusedNode else {
                var result = UnknownLanguageFocusedCodeFinder(proposedSearchRange: 8)
                    .findFocusedCode(
                        containingRange: range,
                        activeDocumentContext: activeDocumentContext
                    )
                result.imports = visitor.imports
                return result
            }
            codeRange = convertRange(focusedNode)
        } else {
            codeRange = range
        }

        let result = EditorInformation
            .code(in: activeDocumentContext.lines, inside: codeRange, ignoreColumns: true)

        var code = result.code

        if range.isEmpty, result.lines.count > maxFocusedCodeLineCount {
            // if the focused code is too long, truncate it to be shorter
            let centerLine = range.start.line
            let relativeCenterLine = centerLine - codeRange.start.line
            let startLine = max(0, relativeCenterLine - maxFocusedCodeLineCount / 2)
            let endLine = max(
                startLine,
                min(result.lines.count - 1, startLine + maxFocusedCodeLineCount - 1)
            )

            code = result.lines[startLine...endLine].joined()
            codeRange = .init(
                start: .init(line: startLine + codeRange.start.line, character: 0),
                end: .init(
                    line: endLine + codeRange.start.line,
                    character: result.lines[endLine].count
                )
            )
        }

        var contextRange = CursorRange.zero
        var signature = [CodeContext.ScopeContext]()

        while let node = nodes.first {
            nodes.removeFirst()
            let (context, more) = contextContainingNode(
                node,
                parentNodes: nodes,
                tree: tree,
                activeDocumentContext: activeDocumentContext,
                locationConverter: locationConverter
            )

            if let context {
                contextRange = context.contextRange
                signature.insert(.init(
                    signature: context.signature,
                    name: context.name,
                    range: context.contextRange
                ), at: 0)
            }

            if !more {
                break
            }
        }

        return .init(
            scope: signature.isEmpty ? .file : .scope(signature: signature),
            contextRange: contextRange,
            focusedRange: codeRange,
            focusedCode: code,
            imports: visitor.imports
        )
    }
}

extension SwiftFocusedCodeFinder {
    struct ContextInfo {
        var signature: String
        var name: String
        var contextRange: CursorRange
        var canBeUsedAsCodeRange: Bool = true
    }

    func contextContainingNode(
        _ node: SyntaxProtocol,
        parentNodes: [SyntaxProtocol],
        tree: SourceFileSyntax,
        activeDocumentContext: ActiveDocumentContext,
        locationConverter: SourceLocationConverter
    ) -> (context: ContextInfo?, more: Bool) {
        func convertRange(_ node: SyntaxProtocol) -> CursorRange {
            .init(sourceRange: node.sourceRange(converter: locationConverter))
        }

        func extractText(_ node: SyntaxProtocol) -> String {
            EditorInformation.code(in: activeDocumentContext.lines, inside: convertRange(node)).code
        }

        switch node {
        case let node as StructDeclSyntax:
            let type = node.structKeyword.text
            let name = node.identifier.text
            return (.init(
                signature: "\(type) \(name)"
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .suffixedInheritance(node.inheritanceClauseTexts(extractText))
                    .replacingOccurrences(of: "\n", with: " "),
                name: name,
                contextRange: convertRange(node)
            ), false)

        case let node as ClassDeclSyntax:
            let type = node.classKeyword.text
            let name = node.identifier.text
            return (.init(
                signature: "\(type) \(name)"
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .suffixedInheritance(node.inheritanceClauseTexts(extractText))
                    .replacingOccurrences(of: "\n", with: " "),
                name: name,
                contextRange: convertRange(node)
            ), false)

        case let node as EnumDeclSyntax:
            let type = node.enumKeyword.text
            let name = node.identifier.text
            return (.init(
                signature: "\(type) \(name)"
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .suffixedInheritance(node.inheritanceClauseTexts(extractText))
                    .replacingOccurrences(of: "\n", with: " "),
                name: name,
                contextRange: convertRange(node)
            ), false)

        case let node as ActorDeclSyntax:
            let type = node.actorKeyword.text
            let name = node.identifier.text
            return (.init(
                signature: "\(type) \(name)"
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .suffixedInheritance(node.inheritanceClauseTexts(extractText))
                    .replacingOccurrences(of: "\n", with: ""),
                name: name,
                contextRange: convertRange(node)
            ), false)

        case let node as MacroDeclSyntax:
            let type = node.macroKeyword.text
            let name = node.identifier.text
            return (.init(
                signature: "\(type) \(name)"
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .replacingOccurrences(of: "\n", with: " "),
                name: name,
                contextRange: convertRange(node)
            ), false)

        case let node as ProtocolDeclSyntax:
            let type = node.protocolKeyword.text
            let name = node.identifier.text
            return (.init(
                signature: "\(type) \(name)"
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .suffixedInheritance(node.inheritanceClauseTexts(extractText))
                    .replacingOccurrences(of: "\n", with: " "),
                name: name,
                contextRange: convertRange(node)
            ), false)

        case let node as ExtensionDeclSyntax:
            let type = node.extensionKeyword.text
            let name = node.extendedType.trimmedDescription
            return (.init(
                signature: "\(type) \(name)"
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .suffixedInheritance(node.inheritanceClauseTexts(extractText))
                    .replacingOccurrences(of: "\n", with: " "),
                name: name,
                contextRange: convertRange(node)
            ), false)

        case let node as FunctionDeclSyntax:
            let type = node.funcKeyword.text
            let name = node.identifier.text
            let signature = node.signature.trimmedDescription
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .joined(separator: " ")

            return (.init(
                signature: "\(type) \(name)\(signature)"
                    .prefixedModifiers(node.modifierAndAttributeText(extractText)),
                name: name,
                contextRange: convertRange(node)
            ), true)

        case let node as VariableDeclSyntax:
            let type = node.bindingSpecifier.trimmedDescription
            let name = node.bindings.first?.pattern.trimmedDescription ?? ""
            let signature = node.bindings.first?.typeAnnotation?.trimmedDescription ?? ""

            return (.init(
                signature: "\(type) \(name)\(signature.isEmpty ? "" : "\(signature)")"
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .replacingOccurrences(of: "\n", with: " "),
                name: name,
                contextRange: convertRange(node),
                canBeUsedAsCodeRange: false
            ), true)

        case let node as AccessorDeclSyntax:
            let keyword = node.accessorSpecifier.text
            let signature = keyword

            return (.init(
                signature: signature
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .replacingOccurrences(of: "\n", with: " "),
                name: keyword,
                contextRange: convertRange(node)
            ), true)

        case let node as SubscriptDeclSyntax:
            let genericPClause = node.genericWhereClause?.trimmedDescription ?? ""
            let pClause = node.parameterClause.trimmedDescription
            let whereClause = node.genericWhereClause?.trimmedDescription ?? ""
            let signature = "subscript\(genericPClause)(\(pClause))\(whereClause)"

            return (.init(
                signature: signature
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .replacingOccurrences(of: "\n", with: " "),
                name: "subscript",
                contextRange: convertRange(node)
            ), true)

        case let node as InitializerDeclSyntax:
            let signature = "init"

            return (.init(
                signature: "\(signature)"
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .replacingOccurrences(of: "\n", with: " "),
                name: "init",
                contextRange: convertRange(node)
            ), true)

        case let node as DeinitializerDeclSyntax:
            let signature = "deinit"

            return (.init(
                signature: signature
                    .prefixedModifiers(node.modifierAndAttributeText(extractText))
                    .replacingOccurrences(of: "\n", with: " "),
                name: "deinit",
                contextRange: convertRange(node)
            ), true)

        case let node as ClosureExprSyntax:
            let signature = "closure"

            return (.init(
                signature: signature.replacingOccurrences(of: "\n", with: " "),
                name: "closure",
                contextRange: convertRange(node)
            ), true)

        case let node as FunctionCallExprSyntax:
            let signature = "function call"

            return (.init(
                signature: signature.replacingOccurrences(of: "\n", with: " "),
                name: "function call",
                contextRange: convertRange(node),
                canBeUsedAsCodeRange: false
            ), true)

        case let node as SwitchCaseSyntax:
            return (.init(
                signature: node.trimmedDescription.replacingOccurrences(of: "\n", with: " "),
                name: "switch",
                contextRange: convertRange(node)
            ), true)

        default:
            return (nil, true)
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
        let locationConverter: SourceLocationConverter

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

        init(
            tree: SyntaxProtocol,
            code: String,
            range: CursorRange,
            locationConverter: SourceLocationConverter
        ) {
            self.tree = tree
            self.code = code
            self.range = range
            self.locationConverter = locationConverter
            super.init(viewMode: .sourceAccurate)
        }

        func skipChildrenIfPossible(_ node: SyntaxProtocol) -> SyntaxVisitorContinueKind {
            if _scopeHierarchy.count > 5 { return .skipChildren }
            if !nodeContainsRange(node) { return .skipChildren }
            return .visitChildren
        }

        func captureNodeIfPossible(_ node: SyntaxProtocol) -> SyntaxVisitorContinueKind {
            if _scopeHierarchy.count > 5 { return .skipChildren }
            if !nodeContainsRange(node) { return .skipChildren }
            _scopeHierarchy.append(node)
            return .visitChildren
        }

        func nodeContainsRange(_ node: SyntaxProtocol) -> Bool {
            let sourceRange = node.sourceRange(converter: locationConverter)
            let cursorRange = CursorRange(sourceRange: sourceRange)
            return cursorRange.strictlyContains(range)
        }

        // skip if possible

        override func visit(_ node: MemberDeclBlockSyntax) -> SyntaxVisitorContinueKind {
            skipChildrenIfPossible(node)
        }

        override func visit(_ node: MemberDeclListItemSyntax) -> SyntaxVisitorContinueKind {
            skipChildrenIfPossible(node)
        }

        // capture if possible

        override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
            imports.append(node.path.trimmedDescription)
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

