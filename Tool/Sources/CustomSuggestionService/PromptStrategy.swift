import CopilotForXcodeKit
import Foundation

public protocol PromptStrategy {
    /// An instruction to the AI model to generate a completion.
    var systemPrompt: String { get }
    /// The source code before the text cursor. Represented as an array of lines.
    var prefix: [String] { get }
    /// The source code after the text cursor. Represented as an array of lines.
    var suffix: [String] { get }
    /// The prefix that should be prepended to the response. By default the last element of
    /// `prefix`.
    var suggestionPrefix: SuggestionPrefix { get }
    /// The relevant code snippets that the AI model should consider when generating a completion.
    var relevantCodeSnippets: [RelevantCodeSnippet] { get }
    /// The words at which the AI model should stop generating the completion.
    var stopWords: [String] { get }
    /// The language of the source code.
    var language: CodeLanguage? { get }
    /// If the prompt generated is raw.
    var promptIsRaw: Bool { get }

    /// Creates a prompt about the source code and relevant code snippets to be sent to the AI
    /// model.
    ///
    /// - Parameters:
    ///  - truncatedPrefix: The truncated source code before the text cursor.
    ///  - truncatedSuffix: The truncated source code after the text cursor.
    ///  - includedSnippets: The relevant code snippets to be included in the prompt.
    ///
    /// - Warning: Please make sure that the prompt won't cause the whole prompt to
    /// exceed the token limit.
    func createPrompt(
        truncatedPrefix: [String],
        truncatedSuffix: [String],
        includedSnippets: [RelevantCodeSnippet]
    ) -> [PromptMessage]
}

/// A meesage in prompt.
public struct PromptMessage {
    public enum PromptRole {
        case user
        case assistant
        public static var prefix: PromptRole { .user }
        public static var suffix: PromptRole { .assistant }
    }

    public var role: PromptRole
    public var content: String

    public init(role: PromptRole, content: String) {
        self.role = role
        self.content = content
    }
}

/// The last line of the prefix.
public struct SuggestionPrefix {
    /// The original value.
    public var original: String
    /// The value to be in the prompt. This value can be different than the ``original`` value. Use
    /// it to tweak the prompt to make the AI model generate a better completion.
    ///
    /// For example, it the last character is `{`, we may want to start the generation from the
    /// next line.
    public var infillValue: String
    /// The value to be prepended to the response that is generated from the ``infillValue``.
    ///
    /// For example, if we appended `// write some code` in the ``infillValue`` to make the model
    /// generate code instead of comments, we may not want to include this line in the final
    /// suggestion.
    public var prependingValue: String

    public static var empty: SuggestionPrefix {
        .init(original: "", infillValue: "", prependingValue: "")
    }

    public static func unchanged(_ string: String) -> SuggestionPrefix {
        .init(original: string, infillValue: string, prependingValue: string)
    }

    public init(original: String, infillValue: String, prependingValue: String) {
        self.original = original
        self.infillValue = infillValue
        self.prependingValue = prependingValue
    }
}

// MARK: - Default Implementations

public extension PromptStrategy {
    var suggestionPrefix: SuggestionPrefix {
        guard let prefix = prefix.last else { return .empty }
        return .unchanged(prefix)
    }
    
    var promptIsRaw: Bool { false }
}

