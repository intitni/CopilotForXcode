import ASTParser
import Foundation
import OpenAIService
import SuggestionModel

struct MoveToFocusedCodeFunction: ChatGPTFunction {
    typealias Arguments = NoArguments

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
        "moveToFocusedCode"
    }

    var description: String {
        "Move editing document context to the selected or focused code"
    }

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
        contextCollector?.activeDocumentContext?.moveToFocusedCode()
        guard let newContext = contextCollector?.activeDocumentContext?.focusedContext else {
            let progress = "Failed to move to focused code."
            await reportProgress(progress)
            throw E(errorDescription: progress)
        }
        let progress = "Looking at \(newContext.codeRange)."
        await reportProgress(progress)
        return .init(range: newContext.codeRange)
    }
}

