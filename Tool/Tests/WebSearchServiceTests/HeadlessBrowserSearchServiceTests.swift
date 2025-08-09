import Foundation
import XCTest

@testable import WebSearchService

class HeadlessBrowserSearchServiceTests: XCTestCase {
    func test_search_on_google() async throws {
        let search = HeadlessBrowserSearchService(engine: .google)
        
        do {
            let result = try await search.search(query: "Snoopy")
            XCTAssertFalse(result.webPages.isEmpty, "Expected non-empty search result")
        } catch {
            XCTFail("Search failed with error: \(error)")
        }
    }
    
    func test_search_on_baidu() async throws {
        let search = HeadlessBrowserSearchService(engine: .baidu)
        
        do {
            let result = try await search.search(query: "Snoopy")
            XCTAssertFalse(result.webPages.isEmpty, "Expected non-empty search result")
        } catch {
            XCTFail("Search failed with error: \(error)")
        }
    }
    
    func test_search_on_duckDuckGo() async throws {
        let search = HeadlessBrowserSearchService(engine: .duckDuckGo)
        
        do {
            let result = try await search.search(query: "Snoopy")
            XCTAssertFalse(result.webPages.isEmpty, "Expected non-empty search result")
        } catch {
            XCTFail("Search failed with error: \(error)")
        }
    }
    
    func test_search_on_bing() async throws {
        let search = HeadlessBrowserSearchService(engine: .bing)
        
        do {
            let result = try await search.search(query: "Snoopy")
            XCTAssertFalse(result.webPages.isEmpty, "Expected non-empty search result")
        } catch {
            XCTFail("Search failed with error: \(error)")
        }
    }
}
