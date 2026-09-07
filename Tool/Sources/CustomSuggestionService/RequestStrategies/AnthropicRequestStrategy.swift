import CopilotForXcodeKit
import Foundation
import AIModel

/// Request strategy optimized for Anthropic's Claude API.
///
/// This strategy is specifically designed to work with Claude's message API format,
/// providing clear and strict instructions for code completion tasks.
struct AnthropicRequestStrategy: RequestStrategy {
    var sourceRequest: SuggestionRequest
    var prefix: [String]
    var suffix: [String]

    var shouldSkip: Bool {
        prefix.last?.trimmingCharacters(in: .whitespaces) == "}"
    }

    func createPrompt() -> Prompt {
        Prompt(
            sourceRequest: sourceRequest,
            prefix: prefix,
            suffix: suffix
        )
    }

    func createStreamStopStrategy(model _: CustomSuggestionCoordinator.Model) -> some StreamStopStrategy {
        OpeningTagBasedStreamStopStrategy(
            openingTag: Tag.openingCode,
            toleranceIfNoOpeningTagFound: 0 // Claude is more precise, we don't need tolerance
        )
    }

    func createRawSuggestionPostProcessor() -> DefaultRawSuggestionPostProcessingStrategy {
        DefaultRawSuggestionPostProcessingStrategy(codeWrappingTags: (
            Tag.openingCode,
            Tag.closingCode
        ))
    }

    enum Tag {
        public static let openingCode = "<Code3721>"
        public static let closingCode = "</Code3721>"
        public static let openingSnippet = "<Snippet9981>"
        public static let closingSnippet = "</Snippet9981>"
    }

    struct Prompt: PromptStrategy {
        let systemPrompt: String = """
        You are a code completion AI with the following STRICT rules:
        1. You MUST ONLY output code within \(Tag.openingCode) and \(Tag.closingCode) tags
        2. You MUST NEVER add explanations, comments, or any text outside the tags
        3. You MUST continue the code exactly where it was left off
        4. You MUST maintain the same style, patterns, and conventions present in the surrounding code
        5. You MUST NOT include any markdown formatting or code block symbols

        Example - if given:
        Complete code inside \(Tag.openingCode):

        \(Tag.openingCode)
        print("Hello
        \(Tag.closingCode)

        You MUST respond EXACTLY:
        \(Tag.openingCode) World")\(Tag.closingCode)

        CRITICAL REQUIREMENTS:
        - Start IMMEDIATELY with \(Tag.openingCode)
        - End IMMEDIATELY with \(Tag.closingCode)
        - NO text before or after the tags
        - NO explanations
        - NO markdown
        - NO commentary
        """.trimmingCharacters(in: .whitespacesAndNewlines)

        var sourceRequest: SuggestionRequest
        var prefix: [String]
        var suffix: [String]
        var filePath: String { sourceRequest.relativePath ?? sourceRequest.fileURL.path }
        var relevantCodeSnippets: [RelevantCodeSnippet] { sourceRequest.relevantCodeSnippets }
        var stopWords: [String] { [Tag.closingCode] } // Removed "\n\n" as Claude does not accept whitespace-only sequences
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
            return [.init(role: .user, content: [
                Self.createSnippetsPrompt(includedSnippets: includedSnippets),
                createSourcePrompt(
                    truncatedPrefix: truncatedPrefix,
                    truncatedSuffix: truncatedSuffix
                ),
            ].filter { !$0.isEmpty }.joined(separator: "\n\n"))]
        }

        func createSourcePrompt(truncatedPrefix: [String], truncatedSuffix: [String]) -> String {
            guard let (summary, infillBlock) = Self.createCodeSummary(
                truncatedPrefix: truncatedPrefix,
                truncatedSuffix: truncatedSuffix,
                suggestionPrefix: suggestionPrefix.infillValue
            ) else { return "" }

            return """
            Below is the code from file \(filePath) that needs completion.
            You MUST:
            1. Analyze the code's style, patterns, and conventions
            2. Complete the code maintaining exact formatting
            3. Only output code within \(Tag.openingCode) tags
            4. Never duplicate existing implementations

            File: \(filePath)
            Indentation: \(sourceRequest.indentSize) \(sourceRequest.usesTabsForIndentation ? "tab" : "space")

            Code to complete:
            \(summary)

            Complete code inside \(Tag.openingCode):

            \(Tag.openingCode)\(infillBlock)
            """.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        static func createSnippetsPrompt(includedSnippets: [RelevantCodeSnippet]) -> String {
            guard !includedSnippets.isEmpty else { return "" }
            return """
            Reference code (analyze for patterns and conventions):

            \(includedSnippets.map { snippet in
                "\(Tag.openingSnippet)\n\(snippet.content)\n\(Tag.closingSnippet)"
            }.joined(separator: "\n\n"))
            """.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        static func createCodeSummary(
            truncatedPrefix: [String],
            truncatedSuffix: [String],
            suggestionPrefix: String
        ) -> (summary: String, infillBlock: String)? {
            guard !(truncatedPrefix.isEmpty && truncatedSuffix.isEmpty) else { return nil }
            let promptLinesCount = min(10, max(truncatedPrefix.count, 2))
            let prefixLines = truncatedPrefix.prefix(
                max(0, truncatedPrefix.count - promptLinesCount)
            )
            let promptLines: [String] = {
                let proposed = truncatedPrefix.suffix(promptLinesCount)
                return Array(proposed.dropLast()) + [suggestionPrefix]
            }()

            return (
                summary: "\(prefixLines.joined())\(Tag.openingCode)\(Tag.closingCode)\(truncatedSuffix.joined())",
                infillBlock: promptLines.joined()
            )
        }
    }
}
