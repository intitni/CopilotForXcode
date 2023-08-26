import Foundation

public protocol SuggestionWidgetDataSource {
    func suggestionForFile(at url: URL) async -> SuggestionProvider?
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
}

