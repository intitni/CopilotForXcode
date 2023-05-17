import Foundation

public protocol ChatContextCollector {
    func generateSystemPrompt(oldMessages: [String]) -> String
}
