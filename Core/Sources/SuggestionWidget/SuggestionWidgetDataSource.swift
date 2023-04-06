import Foundation

public protocol SuggestionWidgetDataSource {
    func suggestionForFile(at path: URL) -> (SuggestionProvider)?
    func chatForFile(at path: URL) -> ChatProvider?
}

struct MockWidgetDataSource: SuggestionWidgetDataSource {
    func suggestionForFile(at path: URL) -> (SuggestionProvider)? {
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

    func chatForFile(at path: URL) -> ChatProvider? {
        return nil
    }
}
