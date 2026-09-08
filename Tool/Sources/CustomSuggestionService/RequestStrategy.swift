import CopilotForXcodeKit
import Foundation
import AIModel
import Preferences

/// Prompts may behave differently in different LLMs.
/// This protocol allows for different strategies to be used to generate prompts.
protocol RequestStrategy {
    associatedtype Prompt: PromptStrategy
    associatedtype RawSuggestionPostProcessor: RawSuggestionPostProcessingStrategy
    associatedtype SomeStreamStopStrategy: StreamStopStrategy

    init(sourceRequest: SuggestionRequest, prefix: [String], suffix: [String])

    /// If the request should be skipped.
    var shouldSkip: Bool { get }

    /// Create a prompt to generate code completion.
    func createPrompt() -> Prompt

    /// Control how a stream should stop early.
    func createStreamStopStrategy(model: CustomSuggestionCoordinator.Model) -> SomeStreamStopStrategy

    /// The AI model may not return a suggestion in a ideal format. You can use it to reformat the
    /// suggestions.
    func createRawSuggestionPostProcessor() -> RawSuggestionPostProcessor
}

extension RequestStrategyOption {
    var strategy: any RequestStrategy.Type {
        switch self {
        case .default:
            return DefaultRequestStrategy.self
        case .naive:
            return NaiveRequestStrategy.self
        case .continue:
            return ContinueRequestStrategy.self
        case .codeLlamaFillInTheMiddle:
            return FillInTheMiddleRequestStrategy.self
        case .codeLlamaFillInTheMiddleWithSystemPrompt:
            return FillInTheMiddleWithSystemPromptRequestStrategy.self
        case .anthropic:
            return AnthropicRequestStrategy.self
        }
    }
}

// MARK: - Default Implementations

extension RequestStrategy {
    var shouldSkip: Bool { false }
}

// MARK: - Suggestion Prefix Helpers

extension SuggestionPrefix {
    func curlyBracesLineBreak() -> SuggestionPrefix {
        func mutate(_ string: String) -> String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasSuffix("{") {
                return string + " "
            }
            if trimmed.hasSuffix("}") {
                return string + "\n"
            }
            return string
        }

        let infillValue = mutate(infillValue)
        let prependingValue = mutate(prependingValue)
        return .init(original: original, infillValue: infillValue, prependingValue: prependingValue)
    }
}

