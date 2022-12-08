import CopilotModel
import CopilotService
import XCTest

@testable import Service
@testable import SuggestionInjector

final class GetSuggestionsTests: XCTestCase {
    let mock = MockSuggestionService(completions: [])

    override func setUp() async throws {
        clearEnvironment()
        Environment.createSuggestionService = { [unowned self] _ in self.mock }
    }

    func test_suggestion_should_be_corretly_included_in_code() async throws {
        let service = getService()
        mock.completions = [
            completion(
                text: """
                    var name: String
                    var age: String
                """,
                range: .init(
                    start: .init(line: 1, character: 0),
                    end: .init(line: 2, character: 18)
                )
            ),
        ]

        let content = """
        struct Cat {

        }

        """

        let result = try await service.getSuggestedCode(editorContent: .init(
            content: content,
            lines: content.breakLines(),
            uti: "",
            cursorPosition: .init(line: 0, character: 17),
            tabSize: 1,
            indentSize: 1,
            usesTabsForIndentation: false
        ))

        XCTAssertEqual(
            result.content.breakLines(appendLineBreakToLastLine: true),
            content.breakLines(appendLineBreakToLastLine: true).applying(result.modifications)
        )
        XCTAssertEqual(result.content, """
        struct Cat {

        /*========== Copilot Suggestion 1/1
            var name: String
            var age: String
        *///======== End of Copilot Suggestion
        }

        """)

        XCTAssertEqual(result.newCursor, .init(line: 0, character: 17))
    }

    func test_get_new_suggestions_without_rejecting_previous_suggestions() async throws {
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
        struct Cat {

        /*========== Copilot Suggestion 1/1
            var name: String
            var age: String
        *///======== End of Copilot Suggestion
        }

        """

        let result = try await service.getSuggestedCode(editorContent: .init(
            content: content,
            lines: content.breakLines(appendLineBreakToLastLine: true),
            uti: "",
            cursorPosition: .init(line: 6, character: 1),
            tabSize: 1,
            indentSize: 1,
            usesTabsForIndentation: false
        ))
        XCTAssertEqual(
            Array(result.content.breakLines(appendLineBreakToLastLine: true).dropLast(1)),
            content.breakLines(appendLineBreakToLastLine: true).applying(result.modifications)
        )
        XCTAssertEqual(result.content, """
        struct Cat {

        }
        
        /*========== Copilot Suggestion 1/1

        struct Dog {}
        *///======== End of Copilot Suggestion

        """, "Previous suggestions should be removed.")

        XCTAssertEqual(result.newCursor, .init(line: 2, character: 1))
    }
}
