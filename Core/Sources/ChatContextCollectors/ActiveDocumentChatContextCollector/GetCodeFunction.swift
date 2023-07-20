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
        var relativePath: String
        var code: String
        var range: CursorRange
        var context: CodeContext
        var type: CodeType
        var language: String

        var botReadableContent: String {
            """
            File: \(relativePath)
            Range: \(range)
            \(type.rawValue) code
            ```\(language)
            \(code)
            ```
            \(context)
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
        let range = selectionRange

        await reportProgress("Finish reading code..")
        return .init(
            relativePath: relativePath,
            code: editorContent,
            range: range,
            context: .top,
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
        let code = {
            if editorInformation.selectedContent.isEmpty {
                return editorInformation.selectedLines.first ?? ""
            }
            return editorInformation.selectedContent
        }()

        guard let astReader = createASTReader() else {
            return .init(
                relativePath: relativePath,
                code: code,
                range: selectionRange ?? .zero,
                context: .top,
                type: .selected,
                language: language
            )
        }

        if let selectionRange {
            let context = astReader.contextContainingRange(
                selectionRange,
                in: editorInformation.editorContent?.content ?? ""
            )
            return .init(
                relativePath: relativePath,
                code: code,
                range: selectionRange,
                context: .top,
                type: .selected,
                language: language
            )
        }

        return .init(
            relativePath: relativePath,
            code: "",
            range: selectionRange ?? .zero,
            context: .top,
            type: .focused,
            language: language
        )
    }

    func createASTReader() -> ASTReader? {
        switch editorInformation.language {
        case .builtIn(.swift):
            return SwiftASTReader()
        case .builtIn(.objc), .builtIn(.objcpp):
            return SwiftASTReader()
        default:
            return nil
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

