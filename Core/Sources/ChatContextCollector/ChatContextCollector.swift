import Foundation

public protocol ChatContextCollector {
    func generateSystemPrompt(history: [String], content: String) -> String
}
