import BuiltinExtension
import CopilotForXcodeKit
import Foundation

/// A built-in extension that generates suggestions with user configured models
/// (OpenAI compatible APIs, Ollama, FIM endpoints, Tabby, etc.).
///
/// It was the standalone "Custom Suggestion Service for Copilot for Xcode" app, now merged into
/// the host as a built-in suggestion provider.
public final class CustomModelExtension: BuiltinExtension {
    public static let identifier = "com.intii.CopilotForXcode.CustomModel"

    public var extensionIdentifier: String { Self.identifier }

    public let suggestionService: CustomModelSuggestionService

    public init() {
        suggestionService = .init()
    }

    public func terminate() {}
}
