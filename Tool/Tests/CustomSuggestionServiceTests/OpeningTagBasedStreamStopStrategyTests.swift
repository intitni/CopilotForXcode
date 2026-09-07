import Foundation
import XCTest

@testable import CustomSuggestionService

class OpeningTagBasedStreamStopStrategyTests: XCTestCase {
    func test_no_opening_tag_found_and_not_hitting_limit() {
        let strategy = OpeningTagBasedStreamStopStrategy(
            openingTag: "<Code>",
            toleranceIfNoOpeningTagFound: 3
        )
        let limiter = StreamLineLimiter(lineLimit: 1, strategy: strategy)
        let content = """
        Hello World
        My Friend
        """
        for character in content {
            let result = limiter.push(String(character))
            XCTAssertEqual(result, .continue)
        }
        XCTAssertEqual(limiter.result, content)
    }
    
    func test_no_opening_tag_found_hitting_limit() {
        let strategy = OpeningTagBasedStreamStopStrategy(
            openingTag: "<Code>",
            toleranceIfNoOpeningTagFound: 3
        )
        let limiter = StreamLineLimiter(lineLimit: 1, strategy: strategy)
        let content = """
        Hello World
        My Friend
        How Are You
        I Am Fine
        Thank You
        """
        
        let expected = """
        Hello World
        My Friend
        How Are You
        I Am Fine
        
        """
        
        for character in content {
            let result = limiter.push(String(character))
            if result == .finish(expected) {
                XCTAssertEqual(limiter.result, expected)
                return
            }
        }
        XCTFail("Should return in the loop\n\n\(limiter.result)")
    }
    
    func test_opening_tag_found_not_hitting_limit() {
        let strategy = OpeningTagBasedStreamStopStrategy(
            openingTag: "<Code>",
            toleranceIfNoOpeningTagFound: 3
        )
        let limiter = StreamLineLimiter(lineLimit: 2, strategy: strategy)
        let content = """
        Hello World
        <Code>
        How Are You
        """
        for character in content {
            let result = limiter.push(String(character))
            XCTAssertEqual(result, .continue)
        }
        XCTAssertEqual(limiter.result, content)
    }
    
    func test_opening_tag_found_hitting_limit() {
        let strategy = OpeningTagBasedStreamStopStrategy(
            openingTag: "<Code>",
            toleranceIfNoOpeningTagFound: 3
        )
        let limiter = StreamLineLimiter(lineLimit: 2, strategy: strategy)
        let content = """
        Hello World
        <Code>
        How Are You
        I Am Fine
        Thank You
        """
        
        let expected = """
        Hello World
        <Code>
        How Are You
        I Am Fine
        
        """
        
        for character in content {
            let result = limiter.push(String(character))
            if result == .finish(expected) {
                XCTAssertEqual(limiter.result, expected)
                return
            }
        }
        XCTFail("Should return in the loop\n\n\(limiter.result)")
    }
}

