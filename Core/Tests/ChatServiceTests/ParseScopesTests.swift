import XCTest

@testable import ChatService

final class ParseScopesTests: XCTestCase {
    let parse = DynamicContextController.parseScopes
    
    func test_parse_single_scope() async throws {
        var prompt = "@web hello"
        let scopes = parse(&prompt)
        XCTAssertEqual(scopes, [.web])
        XCTAssertEqual(prompt, "hello")
    }
    
    func test_parse_single_scope_with_prefix() async throws {
        var prompt = "@w hello"
        let scopes = parse(&prompt)
        XCTAssertEqual(scopes, [.web])
        XCTAssertEqual(prompt, "hello")
    }
    
    func test_parse_multiple_spaces() async throws {
        var prompt = "@web                hello"
        let scopes = parse(&prompt)
        XCTAssertEqual(scopes, [.web])
        XCTAssertEqual(prompt, "hello")
    }
    
    func test_parse_no_prefix_at_mark() async throws {
        var prompt = "  @web                hello"
        let scopes = parse(&prompt)
        XCTAssertEqual(scopes, [])
        XCTAssertEqual(prompt, prompt)
    }
    
    func test_parse_multiple_scopes() async throws {
        var prompt = "@web+file+c+s+project hello"
        let scopes = parse(&prompt)
        XCTAssertEqual(scopes, [.web, .code, .sense, .project, .file])
        XCTAssertEqual(prompt, "hello")
    }
}




