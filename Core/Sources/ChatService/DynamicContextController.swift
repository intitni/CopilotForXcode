import Foundation
import OpenAIService
import XcodeInspector

final class DynamicContextController {
    let chatGPTService: any ChatGPTServiceType
    
    init(chatGPTService: any ChatGPTServiceType) {
        self.chatGPTService = chatGPTService
    }
    
    func updatePromptToMatchContent(systemPrompt: String) async throws {
        
    }
}

extension DynamicContextController {
    func getEditorInformation() -> Any? {
        guard let editor = XcodeInspector.shared.focusedEditor else { return nil }
        let content = editor.content
        
        return nil
    }
}
