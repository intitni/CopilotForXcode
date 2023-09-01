import XCTest
@testable import PromptToCodeService

final class ExtractCodeFromChatGPTTests: XCTestCase {
    func test_extract_from_no_code_block() {
        let api = OpenAIPromptToCodeService()
        let result = api.extractCodeAndDescription(from: """
        hello world!
        """)
        
        XCTAssertEqual(result.code, "")
        XCTAssertEqual(result.description, "")
    }
    
    func test_extract_from_incomplete_code_block() {
        let api = OpenAIPromptToCodeService()
        let result = api.extractCodeAndDescription(from: """
        ```swift
        func foo() {}
        """)
        
        XCTAssertEqual(result.code, "func foo() {}")
        XCTAssertEqual(result.description, "")
    }
    
    func test_extract_from_complete_code_block() {
        let api = OpenAIPromptToCodeService()
        let result = api.extractCodeAndDescription(from: """
        ```swift
        func foo() {}
        
        func bar() {}
        ```
        
        Description
        """)
        
        XCTAssertEqual(result.code, "func foo() {}\n\nfunc bar() {}")
        XCTAssertEqual(result.description, "Description")
    }
    
    func test_extract_from_incomplete_code_block_without_language() {
        let api = OpenAIPromptToCodeService()
        let result = api.extractCodeAndDescription(from: """
        ```
        func foo() {}
        """)
        
        XCTAssertEqual(result.code, "func foo() {}")
        XCTAssertEqual(result.description, "")
    }
    
    func test_extract_from_code_block_without_language() {
        let api = OpenAIPromptToCodeService()
        let result = api.extractCodeAndDescription(from: """
        ```
        func foo() {}
        
        func bar() {}
        ```
        
        Description
        """)
        
        XCTAssertEqual(result.code, "func foo() {}\n\nfunc bar() {}")
        XCTAssertEqual(result.description, "Description")
    }
    
}
