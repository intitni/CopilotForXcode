import ASTParser
import Foundation
import OpenAIService
import SuggestionModel

struct GetCodeFunction: ChatGPTFunction {
    enum CodeType: String, Codable {
        case selected
        case focused
    }

    struct Arguments: Codable {
        var codeType: CodeType
    }

    struct Result: ChatGPTFunctionResult {
        struct Context {
            var parentName: String
            var parentType: String
        }

        var relativePath: String
        var code: String
        var range: CursorRange
        var context: Context
        var type: CodeType
        var language: String

        var botReadableContent: String {
            """
            The \(type.rawValue) code is a part of `\(context.parentType) \(context.parentName)` \
            in file \(relativePath).
            Range [\(range.start.line), \(range.start.character)] - \
            [\(range.end.line), \(range.end.character)]
            ```\(language)
            \(code)
            ```
            """
        }
    }

    var reportProgress: (String) async -> Void = { _ in }

    var name: String {
        "getCode"
    }

    var description: String {
        "Get selected or focused code from the active document."
    }

    var argumentSchema: JSONSchemaValue { [
        .type: "object",
        .properties: [:],
    ] }

    func prepare() async {
        await reportProgress("Reading code..")
    }

    func call(arguments: Arguments) async throws -> Result {
        await reportProgress("Reading code..")
        let content = getEditorInformation()
        let selectionRange = content.editorContent?.selections.first ?? .outOfScope
        let editorContent = {
            if selectionRange.start == selectionRange.end {
                return content.editorContent?.content ?? ""
            } else {
                return content.selectedContent
            }
        }()

        let language = content.language.rawValue
        let type = CodeType.selected
        let relativePath = content.documentURL.path
            .replacingOccurrences(of: content.projectURL.path, with: "")
        let context = Result.Context(
            parentName: content.documentURL.lastPathComponent,
            parentType: "File"
        )
        let range = selectionRange

        await reportProgress("Finish reading code..")
        return .init(
            relativePath: relativePath,
            code: editorContent,
            range: range,
            context: context,
            type: type,
            language: language
        )
    }
}

struct GetCodeResultParser {
    let editorInformation: EditorInformation

    func parse() -> GetCodeFunction.Result {
        let language = editorInformation.language.rawValue
        let relativePath = editorInformation.relativePath
        let selectionRange = editorInformation.editorContent?.selections.first

        if let selectionRange, let node = findSmallestScopeContainingRange(selectionRange) {
            let code = {
                if editorInformation.selectedContent.isEmpty {
                    return editorInformation.selectedLines.first ?? ""
                }
                return editorInformation.selectedContent
            }()

            return .init(
                relativePath: relativePath,
                code: code,
                range: selectionRange,
                context: .init(parentName: "", parentType: ""),
                type: .selected,
                language: language
            )
        }

        return .init(
            relativePath: relativePath,
            code: "",
            range: selectionRange ?? .zero,
            context: .init(parentName: "", parentType: ""),
            type: .focused,
            language: language
        )
    }

    func findSmallestScopeContainingRange(_ range: CursorRange) -> ASTNode? {
        guard let language = {
            switch editorInformation.language {
            case .builtIn(.swift):
                return ParsableLanguage.swift
            case .builtIn(.objc), .builtIn(.objcpp):
                return ParsableLanguage.objectiveC
            default:
                return nil
            }
        }() else { return nil }

        let parser = ASTParser(language: language)
        guard let tree = parser.parse(editorInformation.editorContent?.content ?? "")
        else { return nil }

        return tree.smallestNodeContainingRange(range) { node in
            ScopeType.allCases.map { $0.rawValue }.contains(node.nodeType)
        }
    }
}

enum ScopeType: String, CaseIterable {
    case protocolDeclaration = "protocol_declaration"
    case classDeclaration = "class_declaration"
    case functionDeclaration = "function_declaration"
    case propertyDeclaration = "property_declaration"
    case computedProperty = "computed_property"
}

