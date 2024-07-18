import Foundation

public protocol SuggestionWidgetDataSource {
    func suggestionForFile(at url: URL) async -> PresentingCodeSuggestion?
}

struct MockWidgetDataSource: SuggestionWidgetDataSource {
    func suggestionForFile(at url: URL) async -> PresentingCodeSuggestion? {
        return PresentingCodeSuggestion(
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
            currentSuggestionIndex: 0,
            replacingRange: .zero, 
            replacingLines: []
        )
    }
}

