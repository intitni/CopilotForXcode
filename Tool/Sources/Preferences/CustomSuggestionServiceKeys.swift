import AIModel
import Foundation

/// Preference keys of the built-in custom model suggestion provider.
///
/// The raw key strings keep the `CustomSuggestionService-` prefix used by the original standalone
/// "Custom Suggestion Service for Copilot for Xcode" app.
public extension UserDefaultPreferenceKeys {
    /// Either a `CustomModelType` raw value, or the id of a chat model in ``chatModels``.
    var customSuggestionModelId: PreferenceKey<String> {
        .init(
            defaultValue: CustomModelType.default.rawValue,
            key: "CustomSuggestionService-SuggestionChatModelId"
        )
    }


    var customSuggestionCompletionModel: PreferenceKey<UserDefaultsStorageBox<CompletionModel>> {
        .init(
            defaultValue: .init(CompletionModel(
                id: "ID",
                name: "Custom",
                format: .openAI,
                info: .init()
            )),
            key: "CustomSuggestionService-CustomCompletionModel"
        )
    }

    var customSuggestionFIMModel: PreferenceKey<UserDefaultsStorageBox<FIMModel>> {
        .init(
            defaultValue: .init(FIMModel(id: "ID", name: "Custom", format: .mistral, info: .init())),
            key: "CustomSuggestionService-CustomFIMModel"
        )
    }

    var customSuggestionTabbyModel: PreferenceKey<UserDefaultsStorageBox<TabbyModel>> {
        .init(
            defaultValue: .init(.init(
                url: "",
                authorizationMode: .none,
                apiKeyName: "",
                authorizationHeaderName: "",
                username: ""
            )),
            key: "CustomSuggestionService-TabbyModel"
        )
    }

    var customSuggestionRequestStrategyId: PreferenceKey<String> {
        .init(defaultValue: "", key: "CustomSuggestionService-RequestStrategyId")
    }

    /// Per chat-model API options, keyed by `ChatModel.id`.
    var customSuggestionChatModelAPIOptions: PreferenceKey<UserDefaultsStorageBox<[String: ChatModelAPIOptions]>> {
        .init(
            defaultValue: .init([:]),
            key: "CustomSuggestionService-ChatModelAPIOptions"
        )
    }

    /// 0 means stop words only.
    var customSuggestionMaxLines: PreferenceKey<Int> {
        .init(defaultValue: 0, key: "CustomSuggestionService-MaxNumberOfLinesOfSuggestion")
    }

    var customSuggestionMaxGenerationToken: PreferenceKey<Int> {
        .init(defaultValue: 200, key: "CustomSuggestionService-MaxGenerationToken")
    }

    var customSuggestionVerboseLog: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "CustomSuggestionService-VerboseLog")
    }

    var customSuggestionFIMStopToken: PreferenceKey<String> {
        .init(defaultValue: "<EOT>", key: "CustomSuggestionService-FimStopToken")
    }

    var customSuggestionFIMTemplate: PreferenceKey<String> {
        .init(
            defaultValue: "<PRE> {prefix} <SUF>{suffix} <MID>",
            key: "CustomSuggestionService-FimTemplate"
        )
    }

    var customSuggestionFIMPromptIsRaw: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "CustomSuggestionService-FimPromptIsRaw")
    }

    var customSuggestionFIMAttachFileInfo: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "CustomSuggestionService-fimAttachFileInfo")
    }
}
