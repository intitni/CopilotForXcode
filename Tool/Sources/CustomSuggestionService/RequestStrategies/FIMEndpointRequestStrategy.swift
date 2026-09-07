import CopilotForXcodeKit
import Foundation
import AIModel

/// A special strategy for FIM endpoints.
struct FIMEndpointRequestStrategy: RequestStrategy {
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

    func createRawSuggestionPostProcessor() -> some RawSuggestionPostProcessingStrategy {
        DefaultRawSuggestionPostProcessingStrategy(codeWrappingTags: nil)
    }

    func createStreamStopStrategy(model: CustomSuggestionCoordinator.Model) -> some StreamStopStrategy {
        FIMStreamStopStrategy(prefix: prefix)
    }

    struct Prompt: PromptStrategy {
        let systemPrompt: String = ""
        var sourceRequest: SuggestionRequest
        var prefix: [String]
        var suffix: [String]
        var filePath: String { sourceRequest.relativePath ?? sourceRequest.fileURL.path }
        var relevantCodeSnippets: [RelevantCodeSnippet] { sourceRequest.relevantCodeSnippets }
        var stopWords: [String] { [] }
        var language: CodeLanguage? { sourceRequest.language }

        var suggestionPrefix: SuggestionPrefix {
            guard let prefix = prefix.last else { return .empty }
            return .unchanged(prefix)
        }

        init(sourceRequest: SuggestionRequest, prefix: [String], suffix: [String]) {
            self.sourceRequest = sourceRequest

            let prefix = sourceRequest.relevantCodeSnippets.map { $0.content + "\n\n" }
                + prefix

            self.prefix = prefix
            self.suffix = suffix
        }

        func createPrompt(
            truncatedPrefix: [String],
            truncatedSuffix: [String],
            includedSnippets: [RelevantCodeSnippet]
        ) -> [PromptMessage] {
            let suffix = truncatedSuffix.joined()
            let prefixContent = """
            // File Path: \(filePath)
            // Indentation: \
            \(sourceRequest.indentSize) \
            \(sourceRequest.usesTabsForIndentation ? "tab" : "space")
            \(includedSnippets.map(\.content).joined(separator: "\n\n"))
            \(truncatedPrefix.joined())
            """
            
            let suffixContent = suffix.isEmpty ? "\n// End of file" : suffix
            
            return [
                .init(role: .prefix, content: prefixContent),
                .init(role: .suffix, content: suffixContent)
            ]
        }
    }
}

