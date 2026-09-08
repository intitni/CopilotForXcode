import Foundation

/// Which OpenAI endpoint to call for chat models. Defaults to `/v1/responses`; models whose
/// server only speaks `/v1/chat/completions` need the endpoint picker switched per model.
public enum OpenAIChatAPI: String, Codable, CaseIterable, Equatable {
    /// `POST /v1/chat/completions`
    case chatCompletions
    /// `POST /v1/responses`
    case responses
}

/// `reasoning_effort` (Chat Completions) / `reasoning.effort` (Responses).
///
/// The raw value is sent verbatim. When the preference is empty the field is omitted and the
/// request keeps the legacy shape (`temperature`, `stop`, `max_tokens`).
public enum ReasoningEffort: String, Codable, CaseIterable, Equatable {
    case none
    case minimal
    case low
    case medium
    case high
    case xhigh

    /// `low/medium/high/xhigh` add `reasoningTokenBudget` to max output tokens.
    public var addsReasoningTokenBudget: Bool {
        switch self {
        case .none, .minimal: return false
        case .low, .medium, .high, .xhigh: return true
        }
    }
}

/// Per-chat-model API options for the custom suggestion provider.
public struct ChatModelAPIOptions: Codable, Equatable {
    public var api: OpenAIChatAPI
    public var reasoningEffort: ReasoningEffort?
    public var reasoningTokenBudget: Int

    public init(
        api: OpenAIChatAPI = .responses,
        reasoningEffort: ReasoningEffort? = nil,
        reasoningTokenBudget: Int = 1500
    ) {
        self.api = api
        self.reasoningEffort = reasoningEffort
        self.reasoningTokenBudget = reasoningTokenBudget
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        api = try container.decodeIfPresent(OpenAIChatAPI.self, forKey: .api) ?? .responses
        reasoningEffort = try container.decodeIfPresent(
            ReasoningEffort.self,
            forKey: .reasoningEffort
        )
        reasoningTokenBudget = try container.decodeIfPresent(
            Int.self,
            forKey: .reasoningTokenBudget
        ) ?? 1500
    }

    /// Reads options for `modelId`, migrating the old global keys once if needed.
    public static func stored(
        for modelId: String,
        defaults: UserDefaultsType = UserDefaults.shared
    ) -> ChatModelAPIOptions {
        var dict = defaults.value(for: \.customSuggestionChatModelAPIOptions)
        if dict.isEmpty, migrateLegacyGlobals(into: &dict, modelId: modelId, defaults: defaults) {
            defaults.set(dict, for: \.customSuggestionChatModelAPIOptions)
        }
        return dict[modelId] ?? ChatModelAPIOptions()
    }

    public static func update(
        _ options: ChatModelAPIOptions,
        for modelId: String,
        defaults: UserDefaultsType = UserDefaults.shared
    ) {
        var dict = defaults.value(for: \.customSuggestionChatModelAPIOptions)
        if dict.isEmpty {
            _ = migrateLegacyGlobals(into: &dict, modelId: modelId, defaults: defaults)
        }
        dict[modelId] = options
        defaults.set(dict, for: \.customSuggestionChatModelAPIOptions)
    }

    /// Old global preference keys, kept for a one-time compatibility read.
    public static let legacyOpenAIAPIKey = "CustomSuggestionService-OpenAIAPI"
    public static let legacyReasoningEffortKey = "CustomSuggestionService-ReasoningEffort"

    /// Returns true when values were written into `dict`.
    @discardableResult
    public static func migrateLegacyGlobals(
        into dict: inout [String: ChatModelAPIOptions],
        modelId: String,
        defaults: UserDefaultsType
    ) -> Bool {
        let oldAPI = defaults.value(forKey: legacyOpenAIAPIKey) as? String
        let oldEffort = defaults.value(forKey: legacyReasoningEffortKey) as? String
        let hasNonDefaultAPI = oldAPI != nil
        let hasNonDefaultEffort = !(oldEffort ?? "").isEmpty
        guard hasNonDefaultAPI || hasNonDefaultEffort else { return false }

        dict[modelId] = ChatModelAPIOptions(
            api: OpenAIChatAPI(rawValue: oldAPI ?? "") ?? .responses,
            reasoningEffort: oldEffort.flatMap(ReasoningEffort.init(rawValue:))
        )
        defaults.set(nil, forKey: legacyOpenAIAPIKey)
        defaults.set(nil, forKey: legacyReasoningEffortKey)
        return true
    }
}
