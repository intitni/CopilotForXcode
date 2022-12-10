import CopilotModel
import CopilotService
import XCTest

@testable import Service
@testable import SuggestionInjector

final class RejectSuggestionTests: XCTestCase {
    let mock = MockSuggestionService(completions: [])

    override func setUp() async throws {
        clearEnvironment()
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

        let lines = [
            "struct Cat {}\n",
            "\n",
        ]

        let result1 = try await service.getSuggestedCode(editorContent: .init(
            content: lines.joined(),
            lines: lines,
            uti: "",
            cursorPosition: .init(line: 0, character: 0),
            tabSize: 1,
            indentSize: 1,
            usesTabsForIndentation: false
        ))!
        
        let result1Lines = lines.applying(result1.modifications)

        let result2 = try await service.getSuggestionRejectedCode(editorContent: .init(
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
        XCTAssertEqual(result2Lines, lines, "Previous suggestions should be removed.")

        XCTAssertEqual(
            result2.newCursor,
            .init(line: 1, character: 0),
            "cursor inside suggestion should move up"
        )

        let result3 = try await service.getSuggestionRejectedCode(editorContent: .init(
            content: result1Lines.joined(),
            lines: result1Lines,
            uti: "",
            cursorPosition: .init(line: 0, character: 3),
            tabSize: 1,
            indentSize: 1,
            usesTabsForIndentation: false
        ))!

        let result3Lines = result1Lines.applying(result3.modifications)
        XCTAssertEqual(result3Lines.joined(), result3.content)
        XCTAssertEqual(result3Lines, lines, "Previous suggestions should be removed.")

        XCTAssertEqual(result3.newCursor, .init(line: 0, character: 3))
    }
}
