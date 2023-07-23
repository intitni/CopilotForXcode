import ASTParser
import Foundation
import OpenAIService
import SuggestionModel

struct ExpandFocusRangeFunction: ChatGPTFunction {
    struct Arguments: Codable {}

    struct Result: ChatGPTFunctionResult {
        var text: String

        var botReadableContent: String {
            text
        }
    }

    var reportProgress: (String) async -> Void = { _ in }

    var name: String {
        "expandFocusRange"
    }

    var description: String {
        "When you need more context from the code, you can call it to expand focus range to context range in user editing document context"
    }

    var argumentSchema: JSONSchemaValue { [
        .type: "object",
        .properties: [:],
    ] }
    
    weak var contextCollector: ActiveDocumentChatContextCollector?
    
    init(contextCollector: ActiveDocumentChatContextCollector) {
        self.contextCollector = contextCollector
    }

    func prepare() async {
        await reportProgress("Finding the focused code..")
    }

    func call(arguments: Arguments) async throws -> Result {
        await reportProgress("Finding the focused code..")
        contextCollector?.activeDocumentContext?.expandFocusedRangeToContextRange()
        guard let newContext = contextCollector?.activeDocumentContext?.focusedContext else {
            let progress = "Failed to move to focused code."
            await reportProgress(progress)
            return .init(text: progress)
        }
        let progress = "Looking at \(newContext.codeRange) inside \(newContext.context)"
        await reportProgress(progress)
        return .init(text: progress)
    }
}
