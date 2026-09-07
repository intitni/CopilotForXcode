import CopilotForXcodeKit
import Foundation
import AIModel

/// This strategy mixed and rearrange everything naively to make the model think it's writing code
/// at the end of a file.
struct NaiveRequestStrategy: RequestStrategy {
    var sourceRequest: SuggestionRequest
    var prefix: [String]
    var suffix: [String]

    var shouldSkip: Bool {
        prefix.last?.trimmingCharacters(in: .whitespaces) == "}"
    }

    func createPrompt() -> Request {
        Request(
            sourceRequest: sourceRequest,
            prefix: prefix,
            suffix: suffix
        )
    }

    func createRawSuggestionPostProcessor() -> some RawSuggestionPostProcessingStrategy {
        NoOpRawSuggestionPostProcessingStrategy()
    }

    func createStreamStopStrategy(model: CustomSuggestionCoordinator.Model) -> some StreamStopStrategy {
        DefaultStreamStopStrategy()
    }

    struct Request: PromptStrategy {
        let systemPrompt: String = ""
        var sourceRequest: SuggestionRequest
        var prefix: [String]
        var suffix: [String]
        var filePath: String { sourceRequest.relativePath ?? sourceRequest.fileURL.path }
        var relevantCodeSnippets: [RelevantCodeSnippet] { sourceRequest.relevantCodeSnippets }
        var stopWords: [String] { ["\n\n"] }
        var language: CodeLanguage? { sourceRequest.language }

        var suggestionPrefix: SuggestionPrefix {
            guard let prefix = prefix.last else { return .empty }
            return .unchanged(prefix).curlyBracesLineBreak()
        }

        func createPrompt(
            truncatedPrefix: [String],
            truncatedSuffix: [String],
            includedSnippets: [RelevantCodeSnippet]
        ) -> [PromptMessage] {
            let promptLinesCount = min(10, max(truncatedPrefix.count, 2))
            let prefixLines = truncatedPrefix.prefix(truncatedPrefix.count - promptLinesCount)
            let promptLines: [String] = {
                let proposed = truncatedPrefix.suffix(promptLinesCount)
                return Array(proposed.dropLast()) + [suggestionPrefix.infillValue]
            }()

            /// Mix and rearrange the file and relevant code snippets.
            let code = {
                var codes = [String]()
                if !includedSnippets.isEmpty {
                    codes.append(includedSnippets.map(\.content).joined(separator: "\n\n"))
                }
                if !truncatedSuffix.isEmpty {
                    codes.append("""
                    // From the end of the file
                    \(truncatedSuffix.joined())
                    // End
                    """)
                }
                codes.append("\(prefixLines.joined())\(promptLines.joined())")
                return codes.joined(separator: "\n\n")
            }()

            return [.init(role: .user, content: """
            File path: \(filePath)

            ---

            \(code)
            """.trimmingCharacters(in: .whitespacesAndNewlines))]
        }
    }
}

