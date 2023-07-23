import ASTParser
import Foundation
import OpenAIService
import SuggestionModel

struct MoveToCodeAroundLineFunction: ChatGPTFunction {
    struct Arguments: Codable {
        var line: Int
    }

    struct Result: ChatGPTFunctionResult {
        var text: String

        var botReadableContent: String {
            text
        }
    }

    var reportProgress: (String) async -> Void = { _ in }

    var name: String {
        "moveToCodeAroundLine"
    }

    var description: String {
        "Move user editing document context to code around a line when you need to answer a question the code in the line"
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
        await reportProgress("Finding code around..")
    }

    func call(arguments: Arguments) async throws -> Result {
        await reportProgress("Finding code around line \(arguments.line)..")
        contextCollector?.activeDocumentContext?.moveToCodeAroundLine(arguments.line)
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

