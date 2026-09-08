import CopilotForXcodeKit
import Foundation
import XCTest

@testable import CustomSuggestionService

final class StreamingCompletionTests: XCTestCase {
    private func tokens(_ parts: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for part in parts { continuation.yield(part) }
            continuation.finish()
        }
    }

    func test_displayablePrefix_holdsBackWhatCouldStillBecomeAStopWord() {
        let stopWords = ["</Code3721>", "\n\n"]
        XCTAssertEqual(
            CompletionStopWords.displayablePrefix(of: "let a = 1</Code37", stopWords: stopWords),
            "let a = 1"
        )
        XCTAssertEqual(
            CompletionStopWords.displayablePrefix(of: "let a = 1\n", stopWords: stopWords),
            "let a = 1"
        )
        XCTAssertEqual(
            CompletionStopWords.displayablePrefix(of: "let a = 1", stopWords: stopWords),
            "let a = 1"
        )
        XCTAssertEqual(CompletionStopWords.displayablePrefix(of: "<", stopWords: stopWords), "")
        XCTAssertEqual(CompletionStopWords.displayablePrefix(of: "abc", stopWords: []), "abc")
    }

    func test_streamCompletion_reportsGrowingPartialsAndCutsAtTheStopWord() async throws {
        let limiter = StreamLineLimiter(lineLimit: 0, strategy: NeverStreamStopStrategy())
        var partials = [String]()
        let result = try await feedCompletion(
            from: tokens(["let ", "a", " = 1\n", "</Code", "3721>", "junk"]),
            stopWords: ["</Code3721>", "\n\n"],
            limiter: limiter
        ) { partials.append($0) }

        XCTAssertEqual(result, "let a = 1\n")
        XCTAssertEqual(partials, ["let ", "let a", "let a = 1", "let a = 1\n"])
    }

    func test_streamCompletion_finalTextMatchesCollectCompletion() async throws {
        let parts = ["fo", "o\n", "bar\n", "\n", "dropped"]
        let streamed = try await feedCompletion(
            from: tokens(parts),
            stopWords: ["\n\n"],
            limiter: StreamLineLimiter(lineLimit: 0, strategy: NeverStreamStopStrategy())
        ) { _ in }
        let collected = try await collectCompletion(
            from: tokens(parts),
            stopWords: ["\n\n"],
            limiter: StreamLineLimiter(lineLimit: 0, strategy: NeverStreamStopStrategy())
        )
        XCTAssertEqual(streamed, "foo\nbar")
        XCTAssertEqual(streamed, collected)
    }

    func test_streamCompletion_stopsWhereTheLimiterStops() async throws {
        let limiter = StreamLineLimiter(lineLimit: 1, strategy: DefaultStreamStopStrategy())
        var partials = [String]()
        let result = try await feedCompletion(
            from: tokens(["a\n", "b\n", "c"]),
            stopWords: [],
            limiter: limiter
        ) { partials.append($0) }

        XCTAssertEqual(result, "a\n")
        XCTAssertEqual(partials, [])
    }

    func test_streamingEntryPoint_yieldsPartialsThenTheFinalText() async throws {
        let service = ErasedCompletionService(FakeService(parts: ["x", "y", "</Code3721>"]))
        var elements = [String]()
        for try await element in service.streamCompletion(
            FakePrompt(stopWords: ["</Code3721>"]),
            streamStopStrategy: NeverStreamStopStrategy()
        ) {
            elements.append(element)
        }
        XCTAssertEqual(elements, ["x", "xy", "xy"])
    }

    func test_erasedService_propagatesErrors() async {
        struct Boom: Error {}
        let service = ErasedCompletionService(FakeService(parts: ["x"], failure: Boom()))
        var elements = [String]()
        do {
            for try await element in service.streamCompletion(
                FakePrompt(stopWords: []),
                streamStopStrategy: NeverStreamStopStrategy()
            ) {
                elements.append(element)
            }
            XCTFail("expected the error to propagate")
        } catch {
            XCTAssertTrue(error is Boom)
        }
        XCTAssertEqual(elements, ["x"])

        do {
            _ = try await service.getCompletions(
                FakePrompt(stopWords: []),
                streamStopStrategy: NeverStreamStopStrategy(),
                count: 1
            )
            XCTFail("expected the error to propagate")
        } catch {
            XCTAssertTrue(error is Boom)
        }
    }
}

private struct FakeService: CodeCompletionServiceType {
    let parts: [String]
    var failure: Error? = nil

    func getCompletion(_ request: PromptStrategy) async throws -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for part in parts { continuation.yield(part) }
            if let failure {
                continuation.finish(throwing: failure)
            } else {
                continuation.finish()
            }
        }
    }
}

private struct FakePrompt: PromptStrategy {
    var systemPrompt: String = ""
    var prefix: [String] = []
    var suffix: [String] = []
    var relevantCodeSnippets: [RelevantCodeSnippet] = []
    var stopWords: [String]
    var language: CodeLanguage? = nil

    func createPrompt(
        truncatedPrefix: [String],
        truncatedSuffix: [String],
        includedSnippets: [RelevantCodeSnippet]
    ) -> [PromptMessage] {
        []
    }
}
