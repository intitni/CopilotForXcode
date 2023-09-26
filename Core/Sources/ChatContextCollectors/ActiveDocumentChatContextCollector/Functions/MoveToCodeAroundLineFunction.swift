import ASTParser
import Foundation
import OpenAIService
import SuggestionModel

struct MoveToCodeAroundLineFunction: ChatGPTFunction {
    struct Arguments: Codable {
        var line: Int
    }

    struct Result: ChatGPTFunctionResult {
        var range: CursorRange

        var botReadableContent: String {
            "Editing Document Context is updated to display code at \(range)."
        }
    }

    struct E: Error, LocalizedError {
        var errorDescription: String?
    }

    var name: String {
        "getCodeAtLine"
    }

    var description: String {
        "Get the code at the given line, so you can answer the question about the code at that line."
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

    init(contextCollector: ActiveDocumentChatContextCollector) {
        self.contextCollector = contextCollector
    }

    func prepare(reportProgress: @escaping (String) async -> Void) async {
        await reportProgress("Finding code around..")
    }

    func call(
        arguments: Arguments,
        reportProgress: @escaping (String) async -> Void
    ) async throws -> Result {
        await reportProgress("Finding code around line \(arguments.line)..")
        contextCollector?.activeDocumentContext?.moveToCodeAroundLine(arguments.line)
        guard let newContext = contextCollector?.activeDocumentContext?.focusedContext else {
            let progress = "Failed to move to focused code."
            await reportProgress(progress)
            throw E(errorDescription: progress)
        }
        let progress = "Looking at \(newContext.codeRange)"
        await reportProgress(progress)
        return .init(range: newContext.codeRange)
    }
}

