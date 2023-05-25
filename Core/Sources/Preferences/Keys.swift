import Foundation

public protocol UserDefaultPreferenceKey {
    associatedtype Value
    var defaultValue: Value { get }
    var key: String { get }
}

public struct PreferenceKey<T>: UserDefaultPreferenceKey {
    public let defaultValue: T
    public let key: String
}

public struct FeatureFlag: UserDefaultPreferenceKey {
    public let defaultValue: Bool
    public let key: String
}

public struct UserDefaultPreferenceKeys {
    public init() {}

    // MARK: Quit XPC Service On Xcode And App Quit

    public let quitXPCServiceOnXcodeAndAppQuit = PreferenceKey(
        defaultValue: true,
        key: "QuitXPCServiceOnXcodeAndAppQuit"
    )

    // MARK: Automatically Check For Update

    public let automaticallyCheckForUpdate = PreferenceKey(
        defaultValue: false,
        key: "AutomaticallyCheckForUpdate"
    )

    // MARK: Suggestion Widget Position Mode

    public let suggestionWidgetPositionMode = PreferenceKey(
        defaultValue: SuggestionWidgetPositionMode.fixedToBottom,
        key: "SuggestionWidgetPositionMode"
    )

    // MARK: Widget Color Scheme

    public let widgetColorScheme = PreferenceKey(
        defaultValue: WidgetColorScheme.dark,
        key: "WidgetColorScheme"
    )

    // MARK: Force Order Widget to Front

    public let forceOrderWidgetToFront = PreferenceKey(
        defaultValue: true,
        key: "ForceOrderWidgetToFront"
    )

    // MARK: Prefer Widget to Stay Inside Editor When Width Greater Than

    public let preferWidgetToStayInsideEditorWhenWidthGreaterThan = PreferenceKey(
        defaultValue: 1400 as Double,
        key: "PreferWidgetToStayInsideEditorWhenWidthGreaterThan"
    )
}

// MARK: - OpenAI Account Settings

public extension UserDefaultPreferenceKeys {
    var openAIAPIKey: PreferenceKey<String> {
        .init(defaultValue: "", key: "OpenAIAPIKey")
    }

    @available(*, deprecated, message: "Use `openAIBaseURL` instead.")
    var chatGPTEndpoint: PreferenceKey<String> {
        .init(defaultValue: "", key: "ChatGPTEndpoint")
    }

    var openAIBaseURL: PreferenceKey<String> {
        .init(defaultValue: "", key: "OpenAIBaseURL")
    }

    var chatGPTModel: PreferenceKey<String> {
        .init(defaultValue: Preferences.ChatGPTModel.gpt35Turbo.rawValue, key: "ChatGPTModel")
    }

    var chatGPTMaxToken: PreferenceKey<Int> {
        .init(defaultValue: 4000, key: "ChatGPTMaxToken")
    }

    var chatGPTLanguage: PreferenceKey<String> {
        .init(defaultValue: "", key: "ChatGPTLanguage")
    }

    var chatGPTMaxMessageCount: PreferenceKey<Int> {
        .init(defaultValue: 5, key: "ChatGPTMaxMessageCount")
    }

    var chatGPTTemperature: PreferenceKey<Double> {
        .init(defaultValue: 0.7, key: "ChatGPTTemperature")
    }
}

// MARK: - GitHub Copilot Settings

public extension UserDefaultPreferenceKeys {
    var gitHubCopilotVerboseLog: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "GitHubCopilotVerboseLog")
    }

    var nodePath: PreferenceKey<String> {
        .init(defaultValue: "", key: "NodePath")
    }

    var runNodeWith: PreferenceKey<NodeRunner> {
        .init(defaultValue: .env, key: "RunNodeWith")
    }
}

// MARK: - Codeium Settings

public extension UserDefaultPreferenceKeys {
    var codeiumVerboseLog: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "CodeiumVerboseLog")
    }
}

// MARK: - Prompt to Code

public extension UserDefaultPreferenceKeys {
    var promptToCodeFeatureProvider: PreferenceKey<PromptToCodeFeatureProvider> {
        .init(defaultValue: .openAI, key: "PromptToCodeFeatureProvider")
    }

    var promptToCodeGenerateDescription: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "PromptToCodeGenerateDescription")
    }

    var promptToCodeGenerateDescriptionInUserPreferredLanguage: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "PromptToCodeGenerateDescriptionInUserPreferredLanguage")
    }
}

// MARK: - Suggestion

public extension UserDefaultPreferenceKeys {
    var suggestionFeatureProvider: PreferenceKey<SuggestionFeatureProvider> {
        .init(defaultValue: .gitHubCopilot, key: "SuggestionFeatureProvider")
    }

    var realtimeSuggestionToggle: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "RealtimeSuggestionToggle")
    }

    var suggestionCodeFontSize: PreferenceKey<Double> {
        .init(defaultValue: 13, key: "SuggestionCodeFontSize")
    }

    var disableSuggestionFeatureGlobally: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "DisableSuggestionFeatureGlobally")
    }

    var suggestionFeatureEnabledProjectList: PreferenceKey<[String]> {
        .init(defaultValue: [], key: "SuggestionFeatureEnabledProjectList")
    }

    var suggestionFeatureDisabledLanguageList: PreferenceKey<[String]> {
        .init(defaultValue: [], key: "SuggestionFeatureDisabledLanguageList")
    }

    var hideCommonPrecedingSpacesInSuggestion: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "HideCommonPrecedingSpacesInSuggestion")
    }

    var acceptSuggestionWithAccessibilityAPI: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "AcceptSuggestionWithAccessibilityAPI")
    }

    var suggestionPresentationMode: PreferenceKey<PresentationMode> {
        .init(defaultValue: .floatingWidget, key: "SuggestionPresentationMode")
    }

    var realtimeSuggestionDebounce: PreferenceKey<Double> {
        .init(defaultValue: 0, key: "RealtimeSuggestionDebounce")
    }
}

// MARK: - Chat

public extension UserDefaultPreferenceKeys {
    var chatFontSize: PreferenceKey<Double> {
        .init(defaultValue: 12, key: "ChatFontSize")
    }

    var chatCodeFontSize: PreferenceKey<Double> {
        .init(defaultValue: 12, key: "ChatCodeFontSize")
    }

    var useGlobalChat: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "UseGlobalChat")
    }

    var embedFileContentInChatContextIfNoSelection: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "EmbedFileContentInChatContextIfNoSelection")
    }

    var maxEmbeddableFileInChatContextLineCount: PreferenceKey<Int> {
        .init(defaultValue: 100, key: "MaxEmbeddableFileInChatContextLineCount")
    }
}

// MARK: - Custom Commands

public extension UserDefaultPreferenceKeys {
    var customCommands: PreferenceKey<[CustomCommand]> {
        .init(defaultValue: [
            .init(
                commandId: "BuiltInCustomCommandExplainSelection",
                name: "Explain Selection",
                feature: .chatWithSelection(
                    extraSystemPrompt: "",
                    prompt: "Explain the selected code concisely, step-by-step.",
                    useExtraSystemPrompt: true
                )
            ),
            .init(
                commandId: "BuiltInCustomCommandAddDocumentationToSelection",
                name: "Add Documentation to Selection",
                feature: .promptToCode(
                    extraSystemPrompt: "",
                    prompt: "Add documentation on top of the code. Use triple slash if the language supports it.",
                    continuousMode: false,
                    generateDescription: true
                )
            ),
        ], key: "CustomCommands")
    }
}

// MARK: - Feature Flags

public extension UserDefaultPreferenceKeys {
    var disableLazyVStack: FeatureFlag {
        .init(defaultValue: false, key: "FeatureFlag-DisableLazyVStack")
    }

    var preCacheOnFileOpen: FeatureFlag {
        .init(defaultValue: true, key: "FeatureFlag-PreCacheOnFileOpen")
    }

    var runNodeWithInteractiveLoggedInShell: FeatureFlag {
        .init(defaultValue: true, key: "FeatureFlag-RunNodeWithInteractiveLoggedInShell")
    }

    var useCustomScrollViewWorkaround: FeatureFlag {
        .init(defaultValue: true, key: "FeatureFlag-UseCustomScrollViewWorkaround")
    }

    var triggerActionWithAccessibilityAPI: FeatureFlag {
        .init(defaultValue: true, key: "FeatureFlag-TriggerActionWithAccessibilityAPI")
    }
}

