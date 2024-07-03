import ASTParser
import Foundation
import Preferences
import SuggestionBasic
import SwiftParser
import SwiftSyntax

final class SwiftScopeHierarchySyntaxVisitor: SyntaxVisitor {
    let tree: SyntaxProtocol
    let code: String
    let range: CursorRange
    let rangeConverter: (SyntaxProtocol) -> CursorRange

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
        rangeConverter: @escaping (SyntaxProtocol) -> CursorRange
    ) {
        self.tree = tree
        self.code = code
        self.range = range
        self.rangeConverter = rangeConverter
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
        let cursorRange = rangeConverter(node)
        return cursorRange.strictlyContains(range)
    }

    // skip if possible

    override func visit(_ node: MemberBlockSyntax) -> SyntaxVisitorContinueKind {
        skipChildrenIfPossible(node)
    }

    override func visit(_ node: MemberBlockItemSyntax) -> SyntaxVisitorContinueKind {
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

