import AIModel
import Foundation

public protocol UserDefaultPreferenceKey {
    associatedtype Value
    var defaultValue: Value { get }
    var key: String { get }
}

public struct PreferenceKey<T>: UserDefaultPreferenceKey {
    public let defaultValue: T
    public let key: String

    public init(defaultValue: T, key: String) {
        self.defaultValue = defaultValue
        self.key = key
    }
}

public struct DeprecatedPreferenceKey<T> {
    public let defaultValue: T
    public let key: String

    public init(defaultValue: T, key: String) {
        self.defaultValue = defaultValue
        self.key = key
    }
}

public struct FeatureFlag: UserDefaultPreferenceKey {
    public let defaultValue: Bool
    public let key: String

    public init(defaultValue: Bool, key: String) {
        self.defaultValue = defaultValue
        self.key = key
    }
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

    // MARK: Hide Circular Widget

    public let hideCircularWidget = PreferenceKey(
        defaultValue: false,
        key: "HideCircularWidget"
    )

    public let showHideWidgetShortcutGlobally = PreferenceKey(
        defaultValue: false,
        key: "ShowHideWidgetShortcutGlobally"
    )

    // MARK: Update Channel

    public let installBetaBuilds = PreferenceKey(
        defaultValue: false,
        key: "InstallBetaBuilds"
    )
}

// MARK: - OpenAI Account Settings

public extension UserDefaultPreferenceKeys {
    var openAIAPIKey: DeprecatedPreferenceKey<String> {
        .init(defaultValue: "", key: "OpenAIAPIKey")
    }

    var openAIBaseURL: DeprecatedPreferenceKey<String> {
        .init(defaultValue: "", key: "OpenAIBaseURL")
    }

    var chatGPTModel: DeprecatedPreferenceKey<String> {
        .init(defaultValue: ChatGPTModel.gpt35Turbo.rawValue, key: "ChatGPTModel")
    }

    var chatGPTMaxToken: DeprecatedPreferenceKey<Int> {
        .init(defaultValue: 4000, key: "ChatGPTMaxToken")
    }

    var embeddingModel: DeprecatedPreferenceKey<String> {
        .init(
            defaultValue: OpenAIEmbeddingModel.textEmbeddingAda002.rawValue,
            key: "OpenAIEmbeddingModel"
        )
    }
}

// MARK: - Azure OpenAI Settings

public extension UserDefaultPreferenceKeys {
    var azureOpenAIAPIKey: DeprecatedPreferenceKey<String> {
        .init(defaultValue: "", key: "AzureOpenAIAPIKey")
    }

    var azureOpenAIBaseURL: DeprecatedPreferenceKey<String> {
        .init(defaultValue: "", key: "AzureOpenAIBaseURL")
    }

    var azureChatGPTDeployment: DeprecatedPreferenceKey<String> {
        .init(defaultValue: "", key: "AzureChatGPTDeployment")
    }

    var azureEmbeddingDeployment: DeprecatedPreferenceKey<String> {
        .init(defaultValue: "", key: "AzureEmbeddingDeployment")
    }
}

// MARK: - GitHub Copilot Settings

public extension UserDefaultPreferenceKeys {
    var gitHubCopilotVerboseLog: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "GitHubCopilotVerboseLog")
    }

    var gitHubCopilotProxyHost: PreferenceKey<String> {
        .init(defaultValue: "", key: "GitHubCopilotProxyHost")
    }

    var gitHubCopilotProxyPort: PreferenceKey<String> {
        .init(defaultValue: "", key: "GitHubCopilotProxyPort")
    }

    var gitHubCopilotEnterpriseURI: PreferenceKey<String> {
        .init(defaultValue: "", key: "GitHubCopilotEnterpriseURI")
    }

    var gitHubCopilotUseStrictSSL: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "GitHubCopilotUseStrictSSL")
    }

    var gitHubCopilotProxyUsername: PreferenceKey<String> {
        .init(defaultValue: "", key: "GitHubCopilotProxyUsername")
    }

    var gitHubCopilotProxyPassword: PreferenceKey<String> {
        .init(defaultValue: "", key: "GitHubCopilotProxyPassword")
    }

    var nodePath: PreferenceKey<String> {
        .init(defaultValue: "", key: "NodePath")
    }

    var runNodeWith: PreferenceKey<NodeRunner> {
        .init(defaultValue: .env, key: "RunNodeWith")
    }

    var gitHubCopilotLoadKeyChainCertificates: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "GitHubCopilotLoadKeyChainCertificates")
    }

    var gitHubCopilotPretendIDEToBeVSCode: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "GitHubCopilotPretendIDEToBeVSCode")
    }
}

// MARK: - Codeium Settings

public extension UserDefaultPreferenceKeys {
    var codeiumVerboseLog: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "CodeiumVerboseLog")
    }

    var codeiumEnterpriseMode: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "CodeiumEnterpriseMode")
    }

    var codeiumPortalUrl: PreferenceKey<String> {
        .init(defaultValue: "", key: "CodeiumPortalUrl")
    }

    var codeiumApiUrl: PreferenceKey<String> {
        .init(defaultValue: "", key: "CodeiumApiUrl")
    }

    var codeiumEnterpriseVersion: PreferenceKey<String> {
        .init(defaultValue: "", key: "CodeiumEnterpriseVersion")
    }

    var codeiumIndexEnabled: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "CodeiumIndexEnabled")
    }

    var codeiumIndexingMaxFileSize: PreferenceKey<Int> {
        .init(defaultValue: 5000, key: "CodeiumIndexingMaxFileSize")
    }
}

// MARK: - Chat Models

public extension UserDefaultPreferenceKeys {
    var chatModels: PreferenceKey<[ChatModel]> {
        .init(defaultValue: [
            .init(
                id: UUID().uuidString,
                name: "OpenAI",
                format: .openAI,
                info: .init(
                    apiKeyName: "",
                    baseURL: "",
                    isFullURL: false,
                    maxTokens: ChatGPTModel.gpt35Turbo.maxToken,
                    supportsFunctionCalling: true,
                    modelName: ChatGPTModel.gpt35Turbo.rawValue
                )
            ),
        ], key: "ChatModels")
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

// MARK: - Embedding Models

public extension UserDefaultPreferenceKeys {
    var embeddingModels: PreferenceKey<[EmbeddingModel]> {
        .init(defaultValue: [
            .init(
                id: UUID().uuidString,
                name: "OpenAI",
                format: .openAI,
                info: .init(
                    apiKeyName: "",
                    baseURL: "",
                    isFullURL: false,
                    maxTokens: OpenAIEmbeddingModel.textEmbeddingAda002.maxToken,
                    modelName: OpenAIEmbeddingModel.textEmbeddingAda002.rawValue
                )
            ),
        ], key: "EmbeddingModels")
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

    var promptToCodeChatModelId: PreferenceKey<String> {
        .init(defaultValue: "", key: "PromptToCodeChatModelId")
    }

    var promptToCodeEmbeddingModelId: PreferenceKey<String> {
        .init(defaultValue: "", key: "PromptToCodeEmbeddingModelId")
    }

    var enableSenseScopeByDefaultInPromptToCode: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "EnableSenseScopeByDefaultInPromptToCode")
    }

    var promptToCodeCodeFontSize: PreferenceKey<Double> {
        .init(defaultValue: 13, key: "PromptToCodeCodeFontSize")
    }

    var hideCommonPrecedingSpacesInPromptToCode: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "HideCommonPrecedingSpacesInPromptToCode")
    }

    var wrapCodeInPromptToCode: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "WrapCodeInPromptToCode")
    }
}

// MARK: - Suggestion

public extension UserDefaultPreferenceKeys {
    var oldSuggestionFeatureProvider: DeprecatedPreferenceKey<BuiltInSuggestionFeatureProvider> {
        .init(defaultValue: .gitHubCopilot, key: "SuggestionFeatureProvider")
    }

    var suggestionFeatureProvider: PreferenceKey<SuggestionFeatureProvider> {
        .init(defaultValue: .builtIn(.gitHubCopilot), key: "NewSuggestionFeatureProvider")
    }

    var realtimeSuggestionToggle: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "RealtimeSuggestionToggle")
    }

    var suggestionDisplayCompactMode: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "SuggestionDisplayCompactMode")
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

    var suggestionPresentationMode: PreferenceKey<PresentationMode> {
        .init(defaultValue: .nearbyTextCursor, key: "SuggestionPresentationMode")
    }

    var realtimeSuggestionDebounce: PreferenceKey<Double> {
        .init(defaultValue: 0.2, key: "RealtimeSuggestionDebounce")
    }

    var acceptSuggestionWithTab: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "AcceptSuggestionWithTab")
    }

    var acceptSuggestionWithModifierCommand: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "SuggestionWithModifierCommand")
    }

    var acceptSuggestionWithModifierOption: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "SuggestionWithModifierOption")
    }

    var acceptSuggestionWithModifierControl: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "SuggestionWithModifierControl")
    }

    var acceptSuggestionWithModifierShift: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "SuggestionWithModifierShift")
    }

    var acceptSuggestionWithModifierOnlyForSwift: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "SuggestionWithModifierOnlyForSwift")
    }

    var dismissSuggestionWithEsc: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "DismissSuggestionWithEsc")
    }

    var isSuggestionSenseEnabled: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "IsSuggestionSenseEnabled")
    }

    var isSuggestionTypeInTheMiddleEnabled: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "IsSuggestionTypeInTheMiddleEnabled")
    }
}

// MARK: - Chat

public extension UserDefaultPreferenceKeys {
    var chatFeatureProvider: DeprecatedPreferenceKey<ChatFeatureProvider> {
        .init(defaultValue: .openAI, key: "ChatFeatureProvider")
    }

    var defaultChatFeatureChatModelId: PreferenceKey<String> {
        .init(defaultValue: "", key: "DefaultChatFeatureChatModelId")
    }

    var embeddingFeatureProvider: DeprecatedPreferenceKey<EmbeddingFeatureProvider> {
        .init(defaultValue: .openAI, key: "EmbeddingFeatureProvider")
    }

    var defaultChatFeatureEmbeddingModelId: PreferenceKey<String> {
        .init(defaultValue: "", key: "DefaultChatFeatureEmbeddingModelId")
    }

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

    var maxFocusedCodeLineCount: PreferenceKey<Int> {
        .init(defaultValue: 100, key: "MaxEmbeddableFileInChatContextLineCount")
    }

    var useCodeScopeByDefaultInChatContext: DeprecatedPreferenceKey<Bool> {
        .init(defaultValue: true, key: "UseSelectionScopeByDefaultInChatContext")
    }

    var defaultChatSystemPrompt: PreferenceKey<String> {
        .init(
            defaultValue: """
            You are a helpful senior programming assistant.
            You should respond in natural language.
            Your response should be correct, concise, clear, informative and logical.
            Use markdown if you need to present code, table, list, etc.
            If you are asked to help perform a task, you MUST think step-by-step, then describe each step concisely.
            If you are asked to explain code, you MUST explain it step-by-step in a ordered list concisely.
            Make your answer short and structured.
            """,
            key: "DefaultChatSystemPrompt"
        )
    }

    var chatSearchPluginMaxIterations: PreferenceKey<Int> {
        .init(defaultValue: 3, key: "ChatSearchPluginMaxIterations")
    }

    var wrapCodeInChatCodeBlock: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "WrapCodeInChatCodeBlock")
    }

    var enableFileScopeByDefaultInChatContext: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "EnableFileScopeByDefaultInChatContext")
    }

    var enableCodeScopeByDefaultInChatContext: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "UseSelectionScopeByDefaultInChatContext")
    }

    var enableSenseScopeByDefaultInChatContext: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "EnableSenseScopeByDefaultInChatContext")
    }

    var enableProjectScopeByDefaultInChatContext: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "EnableProjectScopeByDefaultInChatContext")
    }

    var enableWebScopeByDefaultInChatContext: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "EnableWebScopeByDefaultInChatContext")
    }

    var preferredChatModelIdForSenseScope: PreferenceKey<String> {
        .init(defaultValue: "", key: "PreferredChatModelIdForSenseScope")
    }

    var preferredChatModelIdForProjectScope: PreferenceKey<String> {
        .init(defaultValue: "", key: "PreferredChatModelIdForProjectScope")
    }

    var preferredChatModelIdForWebScope: PreferenceKey<String> {
        .init(defaultValue: "", key: "PreferredChatModelIdForWebScope")
    }
    
    var preferredChatModelIdForUtilities: PreferenceKey<String> {
        .init(defaultValue: "", key: "PreferredChatModelIdForUtilities")
    }

    var disableFloatOnTopWhenTheChatPanelIsDetached: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "DisableFloatOnTopWhenTheChatPanelIsDetached")
    }

    var keepFloatOnTopIfChatPanelAndXcodeOverlaps: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "KeepFloatOnTopIfChatPanelAndXcodeOverlaps")
    }

    var openChatMode: PreferenceKey<OpenChatMode> {
        .init(defaultValue: .chatPanel, key: "OpenChatMode")
    }

    var openChatInBrowserURL: PreferenceKey<String> {
        .init(defaultValue: "", key: "OpenChatInBrowserURL")
    }

    var openChatInBrowserInInAppBrowser: PreferenceKey<Bool> {
        .init(defaultValue: true, key: "OpenChatInBrowserInInAppBrowser")
    }
}

// MARK: - Theme

public extension UserDefaultPreferenceKeys {
    var syncSuggestionHighlightTheme: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "SyncSuggestionHighlightTheme")
    }

    var syncPromptToCodeHighlightTheme: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "SyncPromptToCodeHighlightTheme")
    }

    var syncChatCodeHighlightTheme: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "SyncChatCodeHighlightTheme")
    }

    var codeForegroundColorLight: PreferenceKey<UserDefaultsStorageBox<StorableColor?>> {
        .init(defaultValue: .init(nil), key: "CodeForegroundColorLight")
    }

    var codeForegroundColorDark: PreferenceKey<UserDefaultsStorageBox<StorableColor?>> {
        .init(defaultValue: .init(nil), key: "CodeForegroundColorDark")
    }

    var codeBackgroundColorLight: PreferenceKey<UserDefaultsStorageBox<StorableColor?>> {
        .init(defaultValue: .init(nil), key: "CodeBackgroundColorLight")
    }

    var codeBackgroundColorDark: PreferenceKey<UserDefaultsStorageBox<StorableColor?>> {
        .init(defaultValue: .init(nil), key: "CodeBackgroundColorDark")
    }

    var suggestionCodeFont: PreferenceKey<UserDefaultsStorageBox<StorableFont>> {
        .init(
            defaultValue: .init(.init(nsFont: .monospacedSystemFont(ofSize: 12, weight: .regular))),
            key: "SuggestionCodeFont"
        )
    }

    var promptToCodeCodeFont: PreferenceKey<UserDefaultsStorageBox<StorableFont>> {
        .init(
            defaultValue: .init(.init(nsFont: .monospacedSystemFont(ofSize: 12, weight: .regular))),
            key: "PromptToCodeCodeFont"
        )
    }

    var chatCodeFont: PreferenceKey<UserDefaultsStorageBox<StorableFont>> {
        .init(
            defaultValue: .init(.init(nsFont: .monospacedSystemFont(ofSize: 12, weight: .regular))),
            key: "ChatCodeFont"
        )
    }

    var terminalFont: PreferenceKey<UserDefaultsStorageBox<StorableFont>> {
        .init(
            defaultValue: .init(.init(nsFont: .monospacedSystemFont(ofSize: 12, weight: .regular))),
            key: "TerminalCodeFont"
        )
    }
}

// MARK: - Bing Search

public extension UserDefaultPreferenceKeys {
    var bingSearchSubscriptionKey: PreferenceKey<String> {
        .init(defaultValue: "", key: "BingSearchSubscriptionKey")
    }

    var bingSearchEndpoint: PreferenceKey<String> {
        .init(
            defaultValue: "https://api.bing.microsoft.com/v7.0/search/",
            key: "BingSearchEndpoint"
        )
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
            .init(
                commandId: "BuiltInCustomCommandSendCodeToChat",
                name: "Send Selected Code to Chat",
                feature: .chatWithSelection(
                    extraSystemPrompt: "",
                    prompt: """
                    ```{{active_editor_language}}
                    {{selected_code}}
                    ```
                    """,
                    useExtraSystemPrompt: true
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
        .init(defaultValue: false, key: "FeatureFlag-UseCustomScrollViewWorkaround")
    }

    var triggerActionWithAccessibilityAPI: FeatureFlag {
        .init(defaultValue: true, key: "FeatureFlag-TriggerActionWithAccessibilityAPI")
    }

    var alwaysAcceptSuggestionWithAccessibilityAPI: FeatureFlag {
        .init(defaultValue: false, key: "FeatureFlag-AlwaysAcceptSuggestionWithAccessibilityAPI")
    }

    var animationACrashSuggestion: FeatureFlag {
        .init(defaultValue: true, key: "FeatureFlag-AnimationACrashSuggestion")
    }

    var animationBCrashSuggestion: FeatureFlag {
        .init(defaultValue: true, key: "FeatureFlag-AnimationBCrashSuggestion")
    }

    var animationCCrashSuggestion: FeatureFlag {
        .init(defaultValue: true, key: "FeatureFlag-AnimationCCrashSuggestion")
    }

    var enableXcodeInspectorDebugMenu: FeatureFlag {
        .init(defaultValue: false, key: "FeatureFlag-EnableXcodeInspectorDebugMenu")
    }

    var disableFunctionCalling: FeatureFlag {
        .init(defaultValue: false, key: "FeatureFlag-DisableFunctionCalling")
    }

    var useUserDefaultsBaseAPIKeychain: FeatureFlag {
        .init(defaultValue: false, key: "FeatureFlag-UseUserDefaultsBaseAPIKeychain")
    }

    var disableGitHubCopilotSettingsAutoRefreshOnAppear: FeatureFlag {
        .init(
            defaultValue: false,
            key: "FeatureFlag-DisableGitHubCopilotSettingsAutoRefreshOnAppear"
        )
    }

    var disableGitIgnoreCheck: FeatureFlag {
        .init(defaultValue: false, key: "FeatureFlag-DisableGitIgnoreCheck")
    }

    var disableFileContentManipulationByCheatsheet: FeatureFlag {
        .init(defaultValue: true, key: "FeatureFlag-DisableFileContentManipulationByCheatsheet")
    }

    var disableEnhancedWorkspace: FeatureFlag {
        .init(
            defaultValue: false,
            key: "FeatureFlag-DisableEnhancedWorkspace"
        )
    }

    var restartXcodeInspectorIfAccessibilityAPIIsMalfunctioning: FeatureFlag {
        .init(
            defaultValue: false,
            key: "FeatureFlag-RestartXcodeInspectorIfAccessibilityAPIIsMalfunctioning"
        )
    }

    var restartXcodeInspectorIfAccessibilityAPIIsMalfunctioningNoTimer: FeatureFlag {
        .init(
            defaultValue: true,
            key: "FeatureFlag-RestartXcodeInspectorIfAccessibilityAPIIsMalfunctioningNoTimer"
        )
    }

    var toastForTheReasonWhyXcodeInspectorNeedsToBeRestarted: FeatureFlag {
        .init(
            defaultValue: false,
            key: "FeatureFlag-ToastForTheReasonWhyXcodeInspectorNeedsToBeRestarted"
        )
    }

    var observeToAXNotificationWithDefaultMode: FeatureFlag {
        .init(defaultValue: false, key: "FeatureFlag-observeToAXNotificationWithDefaultMode")
    }

    var useCloudflareDomainNameForLicenseCheck: FeatureFlag {
        .init(defaultValue: false, key: "FeatureFlag-UseCloudflareDomainNameForLicenseCheck")
    }
    
    var doNotInstallLaunchAgentAutomatically: FeatureFlag {
        .init(defaultValue: false, key: "FeatureFlag-DoNotInstallLaunchAgentAutomatically")
    }
}

