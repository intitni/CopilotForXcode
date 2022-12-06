import CopilotModel
import XCTest

@testable import SuggestionInjector

final class ProposeSuggestionTests: XCTestCase {
    func test_propose_suggestion_no_overlap() async throws {
        let content = """
        struct Cat {

        }
        """
        let text = """
            var name: String
            var age: String
        """
        let suggestion = CopilotCompletion(
            text: text,
            position: .init(line: 2, character: 19),
            uuid: "",
            range: .init(
                start: .init(line: 1, character: 0),
                end: .init(line: 2, character: 18)
            ),
            displayText: ""
        )

        var lines = content.breakLines()
        SuggestionInjector().proposeSuggestion(
            intoContentWithoutSuggestion: &lines,
            completion: suggestion,
            index: 0,
            count: 10
        )
        XCTAssertEqual(lines.joined(separator: ""), """
        struct Cat {

        /*========== Copilot Suggestion 1/10
            var name: String
            var age: String
        *///======== End of Copilot Suggestion
        }
        """)
    }

    func test_propose_suggestion_no_overlap_start_from_previous_line() async throws {
        let content = """
        struct Cat {
        }
        """
        let text = """
            var name: String
            var age: String
        """
        let suggestion = CopilotCompletion(
            text: text,
            position: .init(line: 1, character: 0),
            uuid: "",
            range: .init(
                start: .init(line: 1, character: 0),
                end: .init(line: 2, character: 18)
            ),
            displayText: ""
        )

        var lines = content.breakLines()
        SuggestionInjector().proposeSuggestion(
            intoContentWithoutSuggestion: &lines,
            completion: suggestion,
            index: 0,
            count: 10
        )
        XCTAssertEqual(lines.joined(separator: ""), """
        struct Cat {
        /*========== Copilot Suggestion 1/10
            var name: String
            var age: String
        *///======== End of Copilot Suggestion
        }
        """)
    }

    func test_propose_suggestion_overlap() async throws {
        let content = """
        struct Cat {
            var name
        }
        """
        let text = """
            var name: String
            var age: String
        """
        let suggestion = CopilotCompletion(
            text: text,
            position: .init(line: 1, character: 0),
            uuid: "",
            range: .init(
                start: .init(line: 1, character: 0),
                end: .init(line: 2, character: 18)
            ),
            displayText: ""
        )

        var lines = content.breakLines()
        SuggestionInjector().proposeSuggestion(
            intoContentWithoutSuggestion: &lines,
            completion: suggestion,
            index: 0,
            count: 10
        )
        XCTAssertEqual(lines.joined(separator: ""), """
        struct Cat {
            var name
        /*========== Copilot Suggestion 1/10
                   ^: String
            var age: String
        *///======== End of Copilot Suggestion
        }
        """)
    }

    // swiftformat:disable indent trailingSpace
    func test_propose_suggestion_overlap_pure_spaces() async throws {
        let content = """
        func quickSort() {
            
        }
        """
        let text = """
            var array = [1, 3, 2, 4, 5, 6, 7, 8, 9, 10]
            var left = 0
            var right = array.count - 1
            quickSort(&array, left, right)
            print(array)
        """
        let suggestion = CopilotCompletion(
            text: text,
            position: .init(line: 1, character: 0),
            uuid: "",
            range: .init(
                start: .init(line: 1, character: 0),
                end: .init(line: 2, character: 18)
            ),
            displayText: ""
        )

        var lines = content.breakLines()
        SuggestionInjector().proposeSuggestion(
            intoContentWithoutSuggestion: &lines,
            completion: suggestion,
            index: 0,
            count: 10
        )
        XCTAssertEqual(lines.joined(separator: ""), """
        func quickSort() {
            
        /*========== Copilot Suggestion 1/10
           ^var array = [1, 3, 2, 4, 5, 6, 7, 8, 9, 10]
            var left = 0
            var right = array.count - 1
            quickSort(&array, left, right)
            print(array)
        *///======== End of Copilot Suggestion
        }
        """)
    }

    // swiftformat:enable all

    func test_propose_suggestion_partial_overlap() async throws {
        let content = "func quickSort() {}}\n"
        let text = """
        func quickSort() {
            var array = [1, 3, 2, 4, 5, 6, 7, 8, 9, 10]
            var left = 0
            var right = array.count - 1
            quickSort(&array, left, right)
            print(array)
        }
        """
        let suggestion = CopilotCompletion(
            text: text,
            position: .init(line: 0, character: 0),
            uuid: "",
            range: .init(
                start: .init(line: 0, character: 0),
                end: .init(line: 5, character: 15)
            ),
            displayText: ""
        )

        var lines = content.breakLines()
        SuggestionInjector().proposeSuggestion(
            intoContentWithoutSuggestion: &lines,
            completion: suggestion,
            index: 0,
            count: 10
        )
        XCTAssertEqual(lines.joined(separator: ""), """
        func quickSort() {}}
        /*========== Copilot Suggestion 1/10
                         ^
            var array = [1, 3, 2, 4, 5, 6, 7, 8, 9, 10]
            var left = 0
            var right = array.count - 1
            quickSort(&array, left, right)
            print(array)
        }
        *///======== End of Copilot Suggestion
        
        """)
    }
}
