import Foundation
import XCTest

@testable import Workspace
@testable import KeyBindingManager

class TabToAcceptSuggestionTests: XCTestCase {
    func test_should_accept_if_line_invalid() {
        XCTAssertTrue(
            TabToAcceptSuggestionHandler.checkIfAcceptSuggestion(
                lines: """
                struct Cat {
                    var name: String
                    var age: Int
                }
                """.breakLines(),
                cursorPosition: .init(line: 4, character: 4),
                codeMetadata: .init(),
                presentingSuggestionText: "Hello"
            )
        )
        
        XCTAssertTrue(
            TabToAcceptSuggestionHandler.checkIfAcceptSuggestion(
                lines: """
                struct Cat {
                    var name: String
                    var age: Int
                }
                """.breakLines(),
                cursorPosition: .init(line: -1, character: 4),
                codeMetadata: .init(),
                presentingSuggestionText: "Hello"
            )
        )
    }
    
    func test_should_not_accept_if_tab_does_not_invalidate_the_suggestion() {
        XCTAssertFalse(
            TabToAcceptSuggestionHandler.checkIfAcceptSuggestion(
                lines: """
                struct Cat {
                
                    var age: Int
                }
                """.breakLines(),
                cursorPosition: .init(line: 1, character: 0),
                codeMetadata: .init(tabSize: 4, indentSize: 4, usesTabsForIndentation: false),
                presentingSuggestionText: "    var name: String"
            )
        )
        
        XCTAssertFalse(
            TabToAcceptSuggestionHandler.checkIfAcceptSuggestion(
                lines: """
                struct 🐱 {
                
                    var 🎇: Int
                }
                """.breakLines(),
                cursorPosition: .init(line: 1, character: 0),
                codeMetadata: .init(tabSize: 4, indentSize: 4, usesTabsForIndentation: false),
                presentingSuggestionText: "    var 🎇: String"
            )
        )
        
        XCTAssertFalse(
            TabToAcceptSuggestionHandler.checkIfAcceptSuggestion(
                lines: """
                struct Cat {
                
                  var age: Int
                }
                """.breakLines(),
                cursorPosition: .init(line: 1, character: 0),
                codeMetadata: .init(tabSize: 2, indentSize: 2, usesTabsForIndentation: false),
                presentingSuggestionText: "  var name: String"
            )
        )
        
        XCTAssertFalse(
            TabToAcceptSuggestionHandler.checkIfAcceptSuggestion(
                lines: """
                struct Cat {
                
                \tvar age: Int
                }
                """.breakLines(),
                cursorPosition: .init(line: 1, character: 0),
                codeMetadata: .init(tabSize: 4, indentSize: 1, usesTabsForIndentation: true),
                presentingSuggestionText: "\tvar name: String"
            )
        )
    }
    
    func test_should_accept_if_tab_invalidates_the_suggestion() {
        XCTAssertTrue(
            TabToAcceptSuggestionHandler.checkIfAcceptSuggestion(
                lines: """
                struct Cat {
                \(" ")
                    var age: Int
                }
                """.breakLines(),
                cursorPosition: .init(line: 1, character: 1),
                codeMetadata: .init(tabSize: 4, indentSize: 4, usesTabsForIndentation: false),
                presentingSuggestionText: "    var name: String"
            )
        )
        
        XCTAssertTrue(
            TabToAcceptSuggestionHandler.checkIfAcceptSuggestion(
                lines: """
                struct 🐱 {
                \(" ")
                    var 🎇: Int
                }
                """.breakLines(),
                cursorPosition: .init(line: 1, character: 1),
                codeMetadata: .init(tabSize: 4, indentSize: 4, usesTabsForIndentation: false),
                presentingSuggestionText: "    var 🎇: String"
            )
        )
        
        XCTAssertTrue(
            TabToAcceptSuggestionHandler.checkIfAcceptSuggestion(
                lines: """
                struct Cat {
                \(" ")
                  var age: Int
                }
                """.breakLines(),
                cursorPosition: .init(line: 1, character: 1),
                codeMetadata: .init(tabSize: 2, indentSize: 2, usesTabsForIndentation: false),
                presentingSuggestionText: "  var name: String"
            )
        )
        
        XCTAssertTrue(
            TabToAcceptSuggestionHandler.checkIfAcceptSuggestion(
                lines: """
                struct Cat {
                \t
                \tvar age: Int
                }
                """.breakLines(),
                cursorPosition: .init(line: 1, character: 1),
                codeMetadata: .init(tabSize: 4, indentSize: 1, usesTabsForIndentation: true),
                presentingSuggestionText: "\tvar name: String"
            )
        )
    }
}
