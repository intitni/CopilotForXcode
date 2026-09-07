import CopilotForXcodeKit
import Foundation
import AIModel

/// The default strategy to generate prompts.
///
/// This strategy tries to believe that the model is smart. It will explain carefully what is what
/// and tell the model to complete the code.
struct DefaultRequestStrategy: RequestStrategy {
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

    func createStreamStopStrategy(model: CustomSuggestionCoordinator.Model) -> some StreamStopStrategy {
        OpeningTagBasedStreamStopStrategy(
            openingTag: Tag.openingCode,
            toleranceIfNoOpeningTagFound: { if case .chatModel = model { 4 } else { 0 } }()
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
        You are a senior programer who take the surrounding code and \
        references from the codebase into account in order to write high-quality code to \
        complete the code enclosed in \(Tag.openingCode) tags. \
        You only respond with code that works and fits seamlessly with surrounding code. \
        Don't include anything else beyond the code.

        Code completion means to keep writing the code. For example, if I tell you to 
        ###
        Complete code inside \(Tag.openingCode):

        \(Tag.openingCode)
        print("Hello
        ###

        You should respond with:
        ###
         World")\(Tag.closingCode)
        ###
        """.trimmingCharacters(in: .whitespacesAndNewlines)
        var sourceRequest: SuggestionRequest
        var prefix: [String]
        var suffix: [String]
        var filePath: String { sourceRequest.relativePath ?? sourceRequest.fileURL.path }
        var relevantCodeSnippets: [RelevantCodeSnippet] { sourceRequest.relevantCodeSnippets }
        var stopWords: [String] { [Tag.closingCode, "\n\n"] }
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
            Below is the code from file \(filePath) that you are trying to complete.
            Review the code carefully, detect the functionality, formats, style, patterns, \
            and logics in use and use them to predict the completion. \
            Make sure your completion has the correct syntax and formatting. \
            Enclose the completion the XML tag \(Tag.openingCode). \
            Don't duplicate existing implementations. \

            File Path: \(filePath)
            Indentation: \
            \(sourceRequest.indentSize) \(sourceRequest.usesTabsForIndentation ? "tab" : "space")

            ---

            Here is the code:
            ```
            \(summary)
            ```

            Complete code inside \(Tag.openingCode):

            \(Tag.openingCode)\(infillBlock)
            """.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        static func createSnippetsPrompt(includedSnippets: [RelevantCodeSnippet]) -> String {
            guard !includedSnippets.isEmpty else { return "" }
            var content = "References from codebase: \n\n"
            for snippet in includedSnippets {
                content += """
                \(Tag.openingSnippet)
                \(snippet.content)
                \(Tag.closingSnippet)
                """ + "\n\n"
            }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
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

