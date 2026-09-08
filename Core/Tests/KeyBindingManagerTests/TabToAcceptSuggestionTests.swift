import Foundation
import XCTest

@testable import Workspace
@testable import KeyBindingManager

class TabToAcceptSuggestionTests: XCTestCase {
    /// Cursor-style: Tab accepts whatever is presented, even when typing a tab would not
    /// invalidate the suggestion (upstream used to pass those Tabs through to Xcode).
    func test_accepts_when_the_suggestion_begins_with_indentation() {
        XCTAssertTrue(
            TabToAcceptSuggestion.checkIfAcceptSuggestion(
                presentingSuggestionText: "    var name: String"
            )
        )
        XCTAssertTrue(
            TabToAcceptSuggestion.checkIfAcceptSuggestion(
                presentingSuggestionText: "\tvar name: String"
            )
        )
    }

    /// The reported case: the completion after `/// ` started with eight spaces, so upstream's
    /// rule needed three Tabs before accepting.
    func test_accepts_when_the_completion_after_the_line_prefix_starts_with_whitespace() {
        XCTAssertTrue(
            TabToAcceptSuggestion.checkIfAcceptSuggestion(
                presentingSuggestionText: "/// " + String(repeating: " ", count: 8)
                    + "))\nlet shareItem = UIBarButtonItem("
            )
        )
    }

    func test_does_not_accept_an_empty_suggestion() {
        XCTAssertFalse(TabToAcceptSuggestion.checkIfAcceptSuggestion(presentingSuggestionText: ""))
    }
}
