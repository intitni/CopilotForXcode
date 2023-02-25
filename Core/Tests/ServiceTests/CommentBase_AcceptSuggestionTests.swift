import CopilotModel
import CopilotService
import XCTest

@testable import Service
@testable import SuggestionInjector

final class AcceptSuggestionTests: XCTestCase {
    let mock = MockSuggestionService(completions: [])

    override func setUp() async throws {
        await clearEnvironment()
        Environment.createSuggestionService = { [unowned self] _ in self.mock }
    }

    func test_accept_suggestion_and_clear_all_sugguestions() async throws {
        let service = CommentBaseCommandHandler()
        mock.completions = [
            completion(
                text: """

                struct Dog {}
                """,
                range: .init(
                    start: .init(line: 1, character: 0),
                    end: .init(line: 1, character: 12)
                )
            ),
        ]

        let lines = [
            "struct Cat {}\n",
            "\n",
        ]

        let result1 = try await service.presentSuggestions(editor: .init(
            content: lines.joined(),
            lines: lines,
            uti: "",
            cursorPosition: .init(line: 0, character: 0),
            tabSize: 1,
            indentSize: 1,
            usesTabsForIndentation: false
        ))!

        let result1Lines = lines.applying(result1.modifications)

        let result2 = try await service.acceptSuggestion(editor: .init(
            content: result1Lines.joined(),
            lines: result1Lines,
            uti: "",
            cursorPosition: .init(line: 3, character: 5),
            tabSize: 1,
            indentSize: 1,
            usesTabsForIndentation: false
        ))!

        let result2Lines = result1Lines.applying(result2.modifications)

        XCTAssertEqual(result2Lines.joined(), result2.content)
        XCTAssertEqual(result2.content, """
        struct Cat {}

        struct Dog {}

        """, "Previous suggestions should be removed.")

        XCTAssertEqual(
            result2.newCursor,
            .init(line: 2, character: 13),
            "Move cursor to the end of suggestion"
        )

        let result3 = try await service.acceptSuggestion(editor: .init(
            content: lines.joined(),
            lines: lines,
            uti: "",
            cursorPosition: .init(line: 0, character: 3),
            tabSize: 1,
            indentSize: 1,
            usesTabsForIndentation: false
        ))

        XCTAssertNil(result3, "Deleting the code and accept again does nothing")
    }
}
