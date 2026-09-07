import AIModel
import Foundation
import Preferences

/// Which OpenAI endpoint to call for chat models.
public enum OpenAIChatAPI: String, CaseIterable {
    /// `POST /v1/chat/completions`
    case chatCompletions
    /// `POST /v1/responses`
    case responses
}

/// `reasoning_effort` (Chat Completions) / `reasoning.effort` (Responses).
///
/// The raw value is sent verbatim. When the preference is empty the field is omitted and the
/// request keeps the legacy shape (`temperature`, `stop`, `max_tokens`).
public enum ReasoningEffort: String, CaseIterable {
    case none
    case minimal
    case low
    case medium
    case high
}

/// Per-request options for chat models, resolved from preferences and the model's custom headers.
struct ChatAPIOptions {
    var api: OpenAIChatAPI
    var reasoningEffort: ReasoningEffort?
    var extraHeaders: [(name: String, value: String)]

    static func current(for model: ChatModel, apiKey: String) -> ChatAPIOptions {
        let api = OpenAIChatAPI(
            rawValue: UserDefaults.shared.value(for: \.customSuggestionOpenAIAPI)
        ) ?? .chatCompletions
        let effort = ReasoningEffort(
            rawValue: UserDefaults.shared.value(for: \.customSuggestionReasoningEffort)
        )
        let headers = model.info.customHeaderInfo.headers
            .filter { !$0.key.isEmpty }
            .map { field in
                (
                    name: field.key,
                    value: substitutePlaceholders(
                        in: field.value,
                        modelName: model.info.modelName,
                        apiKey: apiKey
                    )
                )
            }
        return .init(api: api, reasoningEffort: effort, extraHeaders: headers)
    }

    /// Supports the `{{api_key}}` and `{{model_name}}` placeholders of the host's custom headers.
    static func substitutePlaceholders(in value: String, modelName: String, apiKey: String) -> String {
        value
            .replacingOccurrences(of: "{{api_key}}", with: apiKey)
            .replacingOccurrences(of: "{{model_name}}", with: modelName)
    }
}

extension URLRequest {
    mutating func setExtraHeaders(_ headers: [(name: String, value: String)]) {
        for header in headers {
            setValue(header.value, forHTTPHeaderField: header.name)
        }
    }
}

/// Helpers for `text/event-stream` lines.
enum SSELine {
    /// The payload of a stream line, or nil for lines that carry no data
    /// (blank lines, `event:` / `id:` / `retry:` lines and comments).
    ///
    /// A line without the `data:` prefix is returned as is, so a non-streaming JSON body can be
    /// handled by the same parser.
    static func payload(of line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        for prefix in [":", "event:", "id:", "retry:"] where trimmed.hasPrefix(prefix) {
            return nil
        }
        if trimmed.hasPrefix("data:") {
            return String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        }
        return trimmed
    }
}
