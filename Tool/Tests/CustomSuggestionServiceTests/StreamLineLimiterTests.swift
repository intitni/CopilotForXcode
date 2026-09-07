import Foundation
import XCTest

@testable import CustomSuggestionService

class StreamLineLimiterTests: XCTestCase {
    func test_pushing_characters_without_hitting_limit() {
        let limiter = StreamLineLimiter(lineLimit: 2, strategy: DefaultStreamStopStrategy())
        let content = "hello world\n"
        for character in content {
            let result = limiter.push(String(character))
            XCTAssertEqual(result, .continue)
        }
        XCTAssertEqual(limiter.result, content)
    }

    func test_pushing_characters_hitting_limit() {
        let limiter = StreamLineLimiter(lineLimit: 2, strategy: DefaultStreamStopStrategy())
        let content = "hello world\nhello world\nhello world"
        for character in content {
            let result = limiter.push(String(character))
            if result == .finish("hello world\nhello world\n") {
                XCTAssertEqual(limiter.result, "hello world\nhello world\n")
                return
            }
        }
        XCTFail("Should return in the loop\n\(limiter.result)")
    }

    func test_pushing_characters_with_early_exit_strategy() {
        struct Strategy: StreamStopStrategy {
            func shouldStop(
                existedLines: [String],
                currentLine: String,
                proposedLineLimit: Int
            ) -> StreamStopStrategyResult {
                let hasPrefixP = currentLine.hasPrefix("p")
                let hasNewLine = existedLines.first?.hasSuffix("\n") ?? false
                if hasPrefixP && hasNewLine {
                    return .stop(appendingNewContent: false)
                }
                return .continue
            }
        }

        let limiter = StreamLineLimiter(lineLimit: 10, strategy: Strategy())
        let content = "hello world\npikachu\n"
        for character in content {
            let result = limiter.push(String(character))
            if result == .finish("hello world\n") {
                XCTAssertEqual(limiter.result, "hello world\n")
                return
            }
        }
        XCTFail("Should return in the loop\n\(limiter.result)")
    }

    func test_receiving_multiple_line_ending_as_a_single_token() {
        let limiter = StreamLineLimiter(lineLimit: 4, strategy: DefaultStreamStopStrategy())
        let content = "hello world"
        for character in content {
            let result = limiter.push(String(character))
            XCTAssertEqual(result, .continue)
        }
        XCTAssertEqual(limiter.push("\n\n\n"), .continue)
        XCTAssertEqual(limiter.push("\n"), .finish("hello world\n\n\n\n"))
    }
}

