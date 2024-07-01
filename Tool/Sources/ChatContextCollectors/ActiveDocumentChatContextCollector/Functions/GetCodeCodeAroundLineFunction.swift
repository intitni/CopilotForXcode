import ASTParser
import ChatBasic
import Foundation
import OpenAIService
import SuggestionBasic

struct GetCodeCodeAroundLineFunction: ChatGPTFunction {
    struct Arguments: Codable {
        var line: Int
    }

    struct Result: ChatGPTFunctionResult {
        var range: CursorRange
        var content: String
        var language: CodeLanguage

        var botReadableContent: String {
            """
            Code in range \(range)
            ```\(language.rawValue)
            \(content)
            ```
            """
        }
    }

    struct E: Error, LocalizedError {
        var errorDescription: String?
    }

    var name: String {
        "getCodeAtLine"
    }

    var description: String {
        "Get the code at the given line. \(additionalDescription)"
    }

    var argumentSchema: JSONSchemaValue { [
        .type: "object",
        .properties: [
            "line": [
                .type: "number",
                .description: "The line number in the file",
            ],
        ],
        .required: ["line"],
    ] }

    weak var contextCollector: ActiveDocumentChatContextCollector?
    
    let additionalDescription: String

    init(contextCollector: ActiveDocumentChatContextCollector, additionalDescription: String = "") {
        self.contextCollector = contextCollector
        self.additionalDescription = additionalDescription
    }

    func prepare(reportProgress: @escaping (String) async -> Void) async {
        await reportProgress("Finding code around..")
    }

    func call(
        arguments: Arguments,
        reportProgress: @escaping (String) async -> Void
    ) async throws -> Result {
        guard var activeDocumentContext = contextCollector?.activeDocumentContext else {
            throw E(errorDescription: "No active document found.")
        }
        await reportProgress("Reading code around line \(arguments.line)..")
        activeDocumentContext.moveToCodeAroundLine(max(arguments.line - 1, 0))
        guard let newContext = activeDocumentContext.focusedContext else {
            let progress = "Failed to read code around line \(arguments.line)..)"
            await reportProgress(progress)
            throw E(errorDescription: progress)
        }
        let progress = "Finish reading code at \(newContext.codeRange)"
        await reportProgress(progress)
        return .init(
            range: newContext.codeRange,
            content: newContext.code
                .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                .enumerated()
                .map {
                    let (index, content) = $0
                    if index + newContext.codeRange.start.line == arguments.line - 1 {
                        return content + " // <--- line \(arguments.line)"
                    } else {
                        return content
                    }
                }
                .joined(separator: "\n"),
            language: activeDocumentContext.language
        )
    }
}

