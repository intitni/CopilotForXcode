import CopilotModel
import CopilotService
import XCTest

@testable import SuggestionInjector

final class AcceptSuggestionTests: XCTestCase {
    let mock = MockSuggestionService(completions: [])

    override func setUp() async throws {
        Environment.createSuggestionService = { [unowned self] _ in self.mock }
    }

    func test_accept_suggestion_and_clear_all_sugguestions() async throws {
        let service = getService()
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

        let content = """
        struct Cat {}

        """

        let result1 = try await service.getSuggestedCode(editorContent: .init(
            content: content,
            lines: content.breakLines(appendLineBreakToLastLine: true),
            uti: "",
            cursorPosition: .init(line: 0, character: 0),
            tabSize: 1,
            indentSize: 1,
            usesTabsForIndentation: false
        ))

        let result2 = try await service.getSuggestionAcceptedCode(editorContent: .init(
            content: result1.content,
            lines: result1.content.breakLines(appendLineBreakToLastLine: true),
            uti: "",
            cursorPosition: .init(line: 3, character: 5),
            tabSize: 1,
            indentSize: 1,
            usesTabsForIndentation: false
        ))

        XCTAssertEqual(
            Array(result2.content.breakLines(appendLineBreakToLastLine: true).dropLast(1)),
            result1.content.breakLines(appendLineBreakToLastLine: true).applying(result2.modifications)
        )
        XCTAssertEqual(result2.content, """
        struct Cat {}

        struct Dog {}
        

        """, "Previous suggestions should be removed.")

        XCTAssertEqual(
            result2.newCursor,
            .init(line: 2, character: 13),
            "Move cursor to the end of suggestion"
        )

        let result3 = try await service.getSuggestionAcceptedCode(editorContent: .init(
            content: content,
            lines: content.breakLines(appendLineBreakToLastLine: true),
            uti: "",
            cursorPosition: .init(line: 0, character: 3),
            tabSize: 1,
            indentSize: 1,
            usesTabsForIndentation: false
        ))

        XCTAssertEqual(result3.content, content, "Deleting the code and accept again does nothing")
        XCTAssertEqual(
            result3.content.breakLines(appendLineBreakToLastLine: true),
            content.breakLines(appendLineBreakToLastLine: true).applying(result3.modifications)
        )
        XCTAssertEqual(result3.newCursor, nil)
    }
}
