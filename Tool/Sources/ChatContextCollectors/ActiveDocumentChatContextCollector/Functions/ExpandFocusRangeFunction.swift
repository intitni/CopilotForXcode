import ASTParser
import Foundation
import OpenAIService
import SuggestionModel

struct ExpandFocusRangeFunction: ChatGPTFunction {
    struct Arguments: Codable {}

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
        "expandFocusRange"
    }

    var description: String {
        "Call when Editing Document Context provides too little context to answer a question."
    }

    var argumentSchema: JSONSchemaValue { [
        .type: "object",
        .properties: [:],
    ] }

    weak var contextCollector: ActiveDocumentChatContextCollector?

    init(contextCollector: ActiveDocumentChatContextCollector) {
        self.contextCollector = contextCollector
    }

    func prepare(reportProgress: @escaping (String) async -> Void) async {
        await reportProgress("Finding the focused code..")
    }

    func call(
        arguments: Arguments,
        reportProgress: @escaping (String) async -> Void
    ) async throws -> Result {
        await reportProgress("Finding the focused code..")
        contextCollector?.activeDocumentContext?.expandFocusedRangeToContextRange()
        guard let newContext = contextCollector?.activeDocumentContext?.focusedContext else {
            let progress = "Failed to expand focused code."
            await reportProgress(progress)
            throw E(errorDescription: progress)
        }
        let progress = "Looking at \(newContext.codeRange)."
        await reportProgress(progress)
        return .init(range: newContext.codeRange)
    }
}

