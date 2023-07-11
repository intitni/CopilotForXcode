import XCTest

@testable import ChatService

final class ParseScopesTests: XCTestCase {
    let parse = DynamicContextController.parseScopes
    
    func test_parse_single_scope() async throws {
        var prompt = "@web hello"
        let scopes = parse(&prompt)
        XCTAssertEqual(scopes, ["web"])
        XCTAssertEqual(prompt, "hello")
    }
    
    func test_parse_multiple_spaces() async throws {
        var prompt = "@web                hello"
        let scopes = parse(&prompt)
        XCTAssertEqual(scopes, ["web"])
        XCTAssertEqual(prompt, "hello")
    }
    
    func test_parse_no_prefix_at_mark() async throws {
        var prompt = "  @web                hello"
        let scopes = parse(&prompt)
        XCTAssertEqual(scopes, [])
        XCTAssertEqual(prompt, prompt)
    }
    
    func test_parse_multiple_scopes() async throws {
        var prompt = "@web+file+selection hello"
        let scopes = parse(&prompt)
        XCTAssertEqual(scopes, ["web", "file", "selection"])
        XCTAssertEqual(prompt, "hello")
    }
}




