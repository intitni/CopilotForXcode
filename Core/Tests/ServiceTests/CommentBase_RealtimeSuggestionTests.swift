import CopilotModel
import CopilotService
import Environment
import XCTest
import XPCShared

@testable import Service
@testable import SuggestionInjector

final class CommentBase_RealtimeSuggestionsTests: XCTestCase {
    let mock = MockSuggestionService(completions: [])

    override func setUp() async throws {
        await clearEnvironment()
        Environment.createSuggestionService = { [unowned self] _ in self.mock }
        Environment.triggerAction = { _ in fatalError("unimplemented") }
    }

    func test_if_content_is_changed_no_suggestions_will_be_presented() async throws {
        let service = CommentBaseCommandHandler()
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

        let lines = [
            "struct Cat {\n",
            "\n",
            "}\n",
        ]

        var editor = EditorContent(
            content: lines.joined(),
            lines: lines,
            uti: "",
            cursorPosition: .init(line: 0, character: 17),
            selections: [],
            tabSize: 1,
            indentSize: 1,
            usesTabsForIndentation: false
        )

        Environment.triggerAction = { _ in }

        _ = try await service.generateRealtimeSuggestions(editor: editor)

        editor.cursorPosition = .init(line: 1, character: 17)

        let result = try await service.presentRealtimeSuggestions(editor: editor)

        XCTAssertNil(result)
    }
}
