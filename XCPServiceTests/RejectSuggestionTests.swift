import CopilotModel
import CopilotService
import XCTest

@testable import SuggestionInjector

final class RejectSuggestionTests: XCTestCase {
    let mock = MockSuggestionService(completions: [])

    override func setUp() async throws {
        Environment.createSuggestionService = { [unowned self] _ in self.mock }
    }

    func test_reject_suggestion_and_clear_all_sugguestions() async throws {
        let service = getService()
        mock.completions = [
            completion(
                text: """

                struct Dog {}
                """,
                range: .init(
                    start: .init(line: 7, character: 0),
                    end: .init(line: 7, character: 12)
                )
            ),
        ]

        let content = """
        struct Cat {}

        """

        let result1 = try await service.getSuggestedCode(editorContent: .init(
            content: content,
            lines: content.breakLines(),
            uti: "",
            cursorPosition: .init(line: 0, character: 0),
            tabSize: 1,
            indentSize: 1,
            usesTabsForIndentation: false
        ))

        let result2 = try await service.getSuggestionRejectedCode(editorContent: .init(
            content: result1.content,
            lines: result1.content.breakLines(),
            uti: "",
            cursorPosition: .init(line: 3, character: 5),
            tabSize: 1,
            indentSize: 1,
            usesTabsForIndentation: false
        ))

        XCTAssertEqual(result2.content, content, "Previous suggestions should be removed.")

        XCTAssertEqual(
            result2.newCursor,
            .init(line: 0, character: 0),
            "cursor inside suggestion should move up"
        )

        let result3 = try await service.getSuggestionRejectedCode(editorContent: .init(
            content: result1.content,
            lines: result1.content.breakLines(),
            uti: "",
            cursorPosition: .init(line: 0, character: 3),
            tabSize: 1,
            indentSize: 1,
            usesTabsForIndentation: false
        ))

        XCTAssertEqual(result3.content, content, "Undo deletion and reject again still removes all suggestions it finds.")

        XCTAssertEqual(result3.newCursor, .init(line: 0, character: 3))
    }
}
