import CopilotModel
import CopilotService
import Foundation
import OpenAIService

final class CopilotPromptToCodeAPI: PromptToCodeAPI {
    func stopResponding() {
        fatalError()
    }

    func modifyCode(
        code: String,
        language: CopilotLanguage,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        requirement: String
    ) async throws -> AsyncThrowingStream<(code: String, description: String), Error> {
        fatalError()
    }
}
