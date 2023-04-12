import Foundation

public protocol SuggestionWidgetDataSource {
    func suggestionForFile(at url: URL) async -> SuggestionProvider?
    func chatForFile(at url: URL) async -> ChatProvider?
    func promptToCodeForFile(at url: URL) async -> PromptToCodeProvider?
}

struct MockWidgetDataSource: SuggestionWidgetDataSource {
    func suggestionForFile(at url: URL) async -> SuggestionProvider? {
        return SuggestionProvider(
            code: """
            func test() {
                let x = 1
                let y = 2
                let z = x + y
            }
            """,
            language: "swift",
            startLineIndex: 1,
            suggestionCount: 3,
            currentSuggestionIndex: 0
        )
    }

    func chatForFile(at url: URL) async -> ChatProvider? {
        return nil
    }
    
    func promptToCodeForFile(at url: URL) async -> PromptToCodeProvider? {
        return nil
    }
}
