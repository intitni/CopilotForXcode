import XCTest
@testable import OpenAIService

final class ChatGPTServiceFieldTests: XCTestCase {
    let skip = true
    
    func test_calling_the_api() async throws {
        let service = ChatGPTService()
        
        if skip { return }
        
        do {
            let stream = try await service.send(content: "Hello")
            for try await text in stream {
                print(text)
            }
        } catch {
            print("🔴", error.localizedDescription)
        }
        
        XCTFail("🔴 Please reset skip to true.")
    }
    
    func test_calling_the_api_with_function_calling() async throws {
        let service = ChatGPTService()
        
        if skip { return }
        
        do {
            let stream = try await service.send(content: "Hello")
            for try await text in stream {
                print(text)
            }
        } catch {
            print("🔴", error.localizedDescription)
        }
        
        XCTFail("🔴 Please reset skip to true.")
    }
}
