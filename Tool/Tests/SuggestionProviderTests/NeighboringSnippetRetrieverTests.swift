import Foundation
import SuggestionBasic
import XCTest

@testable import SuggestionProvider

final class CodeTokenizerTests: XCTestCase {
    func test_splits_on_punctuation_and_lowercases() {
        let tokens = CodeTokenizer.tokens(in: ["let workoutSummary = WorkoutStore.shared"])
        XCTAssertTrue(tokens.contains("workoutsummary"))
        XCTAssertTrue(tokens.contains("workoutstore"))
        XCTAssertTrue(tokens.contains("shared"))
    }

    func test_drops_stop_words_and_short_tokens() {
        let tokens = CodeTokenizer.tokens(in: ["let a = self.id"])
        XCTAssertFalse(tokens.contains("let"))
        XCTAssertFalse(tokens.contains("self"))
        XCTAssertFalse(tokens.contains("a"))
        XCTAssertFalse(tokens.contains("id"))
    }

    func test_keeps_underscored_identifiers_whole() {
        let tokens = CodeTokenizer.tokens(in: ["private var _cachedWorkout: Int"])
        XCTAssertTrue(tokens.contains("_cachedworkout"))
    }
}

final class NeighboringSnippetRetrieverTests: XCTestCase {
    let options = NeighboringSnippetRetriever.Options(
        referenceWindow: 40,
        windowSize: 3,
        windowStride: 3,
        maxSnippets: 3,
        maxSnippetsPerFile: 1,
        minimumScore: 0.05
    )

    func makeQuery(_ lines: [String]) -> Set<String> {
        NeighboringSnippetRetriever.queryTokens(
            currentLines: lines,
            cursorPosition: .init(line: lines.count - 1, character: 0),
            options: options
        )
    }

    func test_index_covers_every_line() {
        let source = NeighboringSnippetRetriever.index(
            filePath: "A.swift",
            lines: (0..<7).map { "line\($0)" },
            options: options
        )
        XCTAssertEqual(source.windows.map(\.startLine), [0, 3, 6])
        XCTAssertEqual(source.windows.last?.endLine, 7)
    }

    func test_jaccard_similarity() {
        XCTAssertEqual(NeighboringSnippetRetriever.jaccardSimilarity(["a", "b"], ["a", "b"]), 1)
        XCTAssertEqual(NeighboringSnippetRetriever.jaccardSimilarity(["a", "b"], ["c"]), 0)
        XCTAssertEqual(
            NeighboringSnippetRetriever.jaccardSimilarity(["a", "b"], ["b", "c"]),
            1.0 / 3.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(NeighboringSnippetRetriever.jaccardSimilarity([], ["a"]), 0)
    }

    func test_picks_the_file_that_shares_identifiers() {
        let related = NeighboringSnippetRetriever.index(
            filePath: "WorkoutStore.swift",
            lines: [
                "final class WorkoutStore {",
                "    func loadWorkoutSummary() -> WorkoutSummary { .init() }",
                "}",
            ],
            options: options
        )
        let unrelated = NeighboringSnippetRetriever.index(
            filePath: "NetworkClient.swift",
            lines: [
                "final class NetworkClient {",
                "    func request(path: String) -> Data { .init() }",
                "}",
            ],
            options: options
        )

        let snippets = NeighboringSnippetRetriever.retrieve(
            query: makeQuery(["let summary = WorkoutStore.shared.loadWorkoutSummary()"]),
            sources: [unrelated, related],
            options: options
        )

        XCTAssertEqual(snippets.count, 1)
        XCTAssertEqual(snippets.first?.filePath, "WorkoutStore.swift")
        XCTAssertTrue(snippets.first?.content.hasPrefix("// Path: WorkoutStore.swift\n") ?? false)
        XCTAssertTrue(snippets.first?.content.contains("loadWorkoutSummary") ?? false)
    }

    func test_minimum_score_drops_unrelated_files() {
        let unrelated = NeighboringSnippetRetriever.index(
            filePath: "NetworkClient.swift",
            lines: ["final class NetworkClient {}"],
            options: options
        )
        var strict = options
        strict.minimumScore = 0.9
        let snippets = NeighboringSnippetRetriever.retrieve(
            query: makeQuery(["let summary = WorkoutStore.shared"]),
            sources: [unrelated],
            options: strict
        )
        XCTAssertTrue(snippets.isEmpty)
    }

    func test_respects_per_file_and_total_limits_and_orders_best_first() {
        let lines = (0..<9).map { index in
            index == 3 ? "let workoutSummary = 1" : "let unrelated\(index) = \(index)"
        }
        let source = NeighboringSnippetRetriever.index(
            filePath: "A.swift",
            lines: lines,
            options: options
        )
        let other = NeighboringSnippetRetriever.index(
            filePath: "B.swift",
            lines: ["let workoutSummary = 2"],
            options: options
        )

        let snippets = NeighboringSnippetRetriever.retrieve(
            query: makeQuery(["let workoutSummary = 0"]),
            sources: [source, other],
            options: options
        )

        XCTAssertEqual(snippets.count, 2, "one window per file")
        XCTAssertEqual(snippets.map(\.priority), [2, 1], "best first")
        XCTAssertEqual(snippets.first?.filePath, "B.swift", "the tighter match wins")
    }

    func test_empty_query_returns_nothing() {
        let source = NeighboringSnippetRetriever.index(
            filePath: "A.swift",
            lines: ["let workoutSummary = 1"],
            options: options
        )
        XCTAssertTrue(NeighboringSnippetRetriever.retrieve(
            query: [],
            sources: [source],
            options: options
        ).isEmpty)
    }
}
