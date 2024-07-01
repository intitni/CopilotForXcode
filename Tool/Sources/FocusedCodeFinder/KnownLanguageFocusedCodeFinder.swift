import Foundation
import Preferences
import SuggestionBasic

public typealias KnownLanguageFocusedCodeFinder<Tree, Node, TextPosition> =
    BaseKnownLanguageFocusedCodeFinder<Tree, Node, TextPosition> &
    KnownLanguageFocusedCodeFinderType

public class BaseKnownLanguageFocusedCodeFinder<Tree, Node, TextPosition> {
    public typealias TextProvider = (TextPosition) -> String
    public typealias RangeConverter = (Node) -> CursorRange

    public struct NodeInfo {
        var node: Node
        var signature: String
        var name: String
        var canBeUsedAsCodeRange: Bool = true
    }

    public struct ContextInfo {
        var nodes: [Node]
        var includes: [String]
        var imports: [String]
    }

    public let maxFocusedCodeLineCount: Int

    init(
        maxFocusedCodeLineCount: Int = UserDefaults.shared.value(for: \.maxFocusedCodeLineCount)
    ) {
        self.maxFocusedCodeLineCount = maxFocusedCodeLineCount
    }
}

public protocol KnownLanguageFocusedCodeFinderType: FocusedCodeFinderType {
    associatedtype Tree
    associatedtype Node
    associatedtype TextPosition
    typealias Document = FocusedCodeFinder.Document
    typealias Finder = BaseKnownLanguageFocusedCodeFinder<Tree, Node, TextPosition>
    typealias NodeInfo = Finder.NodeInfo
    typealias ContextInfo = Finder.ContextInfo
    typealias TextProvider = Finder.TextProvider
    typealias RangeConverter = Finder.RangeConverter

    var maxFocusedCodeLineCount: Int { get }

    func parseSyntaxTree(from document: Document) -> Tree?

    func collectContextNodes(
        in document: Document,
        tree: Tree,
        containingRange: SuggestionBasic.CursorRange,
        textProvider: @escaping TextProvider,
        rangeConverter: @escaping RangeConverter
    ) -> ContextInfo

    func contextContainingNode(
        _ node: Node,
        textProvider: @escaping TextProvider,
        rangeConverter: @escaping RangeConverter
    ) -> NodeInfo?

    func createTextProviderAndRangeConverter(
        for document: Document,
        tree: Tree
    ) -> (TextProvider, RangeConverter)
}

public extension KnownLanguageFocusedCodeFinderType {
    func findFocusedCode(
        in document: Document,
        containingRange range: SuggestionBasic.CursorRange
    ) -> CodeContext {
        guard let tree = parseSyntaxTree(from: document) else { return .empty }

        let (textProvider, rangeConverter) = createTextProviderAndRangeConverter(
            for: document,
            tree: tree
        )
        var contextInfo = collectContextNodes(
            in: document,
            tree: tree,
            containingRange: range,
            textProvider: textProvider,
            rangeConverter: rangeConverter
        )
        var codeRange: CursorRange

        let noSelection = range.isEmpty
        if noSelection {
            // use the first scope as code, the second as context
            var focusedNode: Node?
            while let node = contextInfo.nodes.first {
                contextInfo.nodes.removeFirst()
                let nodeInfo = contextContainingNode(
                    node,
                    textProvider: textProvider,
                    rangeConverter: rangeConverter
                )
                if nodeInfo?.canBeUsedAsCodeRange ?? false {
                    focusedNode = node
                    break
                }
            }
            guard let focusedNode else {
                // fallback to unknown language focused code finder when no scope found
                var result = UnknownLanguageFocusedCodeFinder(proposedSearchRange: 8)
                    .findFocusedCode(in: document, containingRange: range)
                result.imports = contextInfo.imports
                result.includes = contextInfo.includes
                return result
            }
            codeRange = rangeConverter(focusedNode)
        } else {
            // use the selection as code, the first scope as context
            codeRange = range
        }

        let (code, _, focusedRange) = extractFocusedCode(
            in: codeRange,
            in: document,
            containingRange: range
        )

        let (contextRange, scopeContexts) = extractScopeContext(
            contextNodes: contextInfo.nodes,
            textProvider: textProvider,
            rangeConverter: rangeConverter
        )

        return .init(
            scope: scopeContexts.isEmpty ? .file : .scope(signature: scopeContexts),
            contextRange: contextRange,
            smallestContextRange: codeRange,
            focusedRange: focusedRange,
            focusedCode: code,
            imports: contextInfo.imports,
            includes: contextInfo.includes
        )
    }
}

extension KnownLanguageFocusedCodeFinderType {
    func extractFocusedCode(
        in codeRange: CursorRange,
        in document: Document,
        containingRange range: SuggestionBasic.CursorRange
    ) -> (code: String, lines: [String], codeRange: CursorRange) {
        var codeRange = codeRange
        let codeInCodeRange = EditorInformation.code(
            in: document.lines,
            inside: codeRange,
            ignoreColumns: true
        )

        var code = codeInCodeRange.code
        var lines = codeInCodeRange.lines

        if range.isEmpty, codeInCodeRange.lines.count > maxFocusedCodeLineCount {
            // if the focused code is too long, truncate it to be shorter
            let centerLine = range.start.line
            let relativeCenterLine = centerLine - codeRange.start.line
            let startLine = max(0, relativeCenterLine - maxFocusedCodeLineCount / 2)
            let endLine = max(
                startLine,
                min(codeInCodeRange.lines.count - 1, startLine + maxFocusedCodeLineCount - 1)
            )

            lines = Array(codeInCodeRange.lines[startLine...endLine])
            code = lines.joined()
            codeRange = .init(
                start: .init(line: startLine + codeRange.start.line, character: 0),
                end: .init(
                    line: endLine + codeRange.start.line,
                    character: codeInCodeRange.lines[endLine].count
                )
            )
        }

        return (code, lines, codeRange)
    }

    func extractScopeContext(
        contextNodes: [Node],
        textProvider: @escaping TextProvider,
        rangeConverter: @escaping RangeConverter
    ) -> (contextRange: CursorRange, scopeContexts: [CodeContext.ScopeContext]) {
        var nodes = contextNodes
        var contextRange = CursorRange.zero
        var signature = [CodeContext.ScopeContext]()

        while let node = nodes.first {
            nodes.removeFirst()
            let context = contextContainingNode(
                node,
                textProvider: textProvider,
                rangeConverter: rangeConverter
            )

            if let context {
                contextRange = rangeConverter(context.node)
                signature.insert(.init(
                    signature: context.signature,
                    name: context.name,
                    range: contextRange
                ), at: 0)
            }
        }

        return (contextRange, signature)
    }
}

