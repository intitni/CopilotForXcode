import CopilotModel
import CopilotService
import XCTest

@testable import SuggestionInjector

final class GetPreviousSuggestionTests: XCTestCase {
    let mock = MockSuggestionService(completions: [])

    override func setUp() async throws {
        Environment.createSuggestionService = { [unowned self] _ in self.mock }
    }

    func test_get_next_suggestions_without_rejecting_previous_suggestions() async throws {
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
            completion(
                text: """

                struct Wolve {}
                """,
                range: .init(
                    start: .init(line: 7, character: 0),
                    end: .init(line: 7, character: 12)
                )
            ),
        ]

        var content = """
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
        
        content = result1.content

        let result2 = try await service.getNextSuggestedCode(editorContent: .init(
            content: content,
            lines: content.breakLines(),
            uti: "",
            cursorPosition: .init(line: 3, character: 5),
            tabSize: 1,
            indentSize: 1,
            usesTabsForIndentation: false
        ))

        XCTAssertEqual(result2.content, """
        struct Cat {}
        /*========== Copilot Suggestion 2/2

        struct Wolve {}
        *///======== End of Copilot Suggestion

        """, "Previous suggestions should be removed.")

        XCTAssertEqual(
            result2.newCursor,
            .init(line: 0, character: 0),
            "The cursor was in the deleted suggestion, reset it to 1 line above the suggestion, set its col to 0"
        )
        
        content = result2.content
        
        let result3 = try await service.getNextSuggestedCode(editorContent: .init(
            content: content,
            lines: content.breakLines(),
            uti: "",
            cursorPosition: .init(line: 0, character: 3),
            tabSize: 1,
            indentSize: 1,
            usesTabsForIndentation: false
        ))
        
        XCTAssertEqual(result3.content, """
        struct Cat {}
        /*========== Copilot Suggestion 1/2

        struct Dog {}
        *///======== End of Copilot Suggestion

        """, "Cycling through the suggestions.")

        XCTAssertEqual( result3.newCursor, .init(line: 0, character: 3) )
    }
}
