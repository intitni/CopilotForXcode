import Foundation

public protocol UserDefaultPreferenceKey {
    associatedtype Value
    var defaultValue: Value { get }
    var key: String { get }
}

public struct UserDefaultPreferenceKeys {
    public init() {}

    // MARK: Quit XPC Service On Xcode And App Quit

    public struct QuitXPCServiceOnXcodeAndAppQuit: UserDefaultPreferenceKey {
        public let defaultValue = true
        public let key = "QuitXPCServiceOnXcodeAndAppQuit"
    }

    public var quitXPCServiceOnXcodeAndAppQuit: QuitXPCServiceOnXcodeAndAppQuit { .init() }

    // MARK: Automatically Check For Update

    public struct AutomaticallyCheckForUpdate: UserDefaultPreferenceKey {
        public let defaultValue = false
        public let key = "AutomaticallyCheckForUpdate"
    }

    public var automaticallyCheckForUpdate: AutomaticallyCheckForUpdate { .init() }

    // MARK: Suggestion Widget Position Mode

    public struct SuggestionWidgetPositionModeKey: UserDefaultPreferenceKey {
        public let defaultValue = SuggestionWidgetPositionMode.fixedToBottom
        public let key = "SuggestionWidgetPositionMode"
    }

    public var suggestionWidgetPositionMode: SuggestionWidgetPositionModeKey { .init() }

    // MARK: Widget Color Scheme

    public struct WidgetColorSchemeKey: UserDefaultPreferenceKey {
        public let defaultValue = WidgetColorScheme.dark
        public let key = "WidgetColorScheme"
    }

    public var widgetColorScheme: WidgetColorSchemeKey { .init() }

    // MARK: Force Order Widget to Front

    public struct ForceOrderWidgetToFront: UserDefaultPreferenceKey {
        public let defaultValue = true
        public let key = "ForceOrderWidgetToFront"
    }

    public var forceOrderWidgetToFront: HideCommonPrecedingSpacesInSuggestion {
        .init()
    }

    // MARK: Prefer Widget to Stay Inside Editor When Width Greater Than

    public struct PreferWidgetToStayInsideEditorWhenWidthGreaterThan: UserDefaultPreferenceKey {
        public let defaultValue = 1400 as Double
        public let key = "PreferWidgetToStayInsideEditorWhenWidthGreaterThan"
    }

    public var preferWidgetToStayInsideEditorWhenWidthGreaterThan: PreferWidgetToStayInsideEditorWhenWidthGreaterThan {
        .init()
    }
}

// MARK: - OpenAI Account Settings

public extension UserDefaultPreferenceKeys {
    struct OpenAIAPIKey: UserDefaultPreferenceKey {
        public let defaultValue = ""
        public let key = "OpenAIAPIKey"
    }

    var openAIAPIKey: OpenAIAPIKey { .init() }

    struct ChatGPTEndpoint: UserDefaultPreferenceKey {
        public let defaultValue = ""
        public let key = "ChatGPTEndpoint"
    }

    var chatGPTEndpoint: ChatGPTEndpoint { .init() }

    struct ChatGPTModel: UserDefaultPreferenceKey {
        public let defaultValue = Preferences.ChatGPTModel.gpt35Turbo.rawValue
        public let key = "ChatGPTModel"
    }

    var chatGPTModel: ChatGPTModel { .init() }

    struct ChatGPTMaxToken: UserDefaultPreferenceKey {
        public let defaultValue = 4000
        public let key = "ChatGPTMaxToken"
    }

    var chatGPTMaxToken: ChatGPTMaxToken { .init() }

    struct ChatGPTLanguage: UserDefaultPreferenceKey {
        public let defaultValue = ""
        public let key = "ChatGPTLanguage"
    }

    var chatGPTLanguage: ChatGPTLanguage { .init() }

    struct ChatGPTMaxMessageCount: UserDefaultPreferenceKey {
        public let defaultValue = 5
        public let key = "ChatGPTMaxMessageCount"
    }

    var chatGPTMaxMessageCount: ChatGPTMaxMessageCount { .init() }

    struct ChatGPTTemperature: UserDefaultPreferenceKey {
        public let defaultValue = 0.7
        public let key = "ChatGPTTemperature"
    }

    var chatGPTTemperature: ChatGPTTemperature { .init() }
}

// MARK: - GitHub Copilot Settings

public extension UserDefaultPreferenceKeys {
    struct GitHubCopilotVerboseLog: UserDefaultPreferenceKey {
        public let defaultValue = false
        public let key = "GitHubCopilotVerboseLog"
    }

    var gitHubCopilotVerboseLog: GitHubCopilotVerboseLog { .init() }

    struct NodePath: UserDefaultPreferenceKey {
        public let defaultValue: String = ""
        public let key = "NodePath"
    }

    var nodePath: NodePath { .init() }

    struct RunNodeWithKey: UserDefaultPreferenceKey {
        public let defaultValue = NodeRunner.bash
        public let key = "RunNodeWith"
    }

    var runNodeWith: RunNodeWithKey { .init() }
}

// MARK: - Codeium Settings

public extension UserDefaultPreferenceKeys {
    struct CodeiumVerboseLog: UserDefaultPreferenceKey {
        public let defaultValue = false
        public let key = "CodeiumVerboseLog"
    }

    var codeiumVerboseLog: CodeiumVerboseLog { .init() }
}

// MARK: - Prompt to Code

public extension UserDefaultPreferenceKeys {
    struct PromptToCodeFeatureProviderKey: UserDefaultPreferenceKey {
        public let defaultValue: PromptToCodeFeatureProvider = .openAI
        public let key = "PromptToCodeFeatureProvider"
    }

    var promptToCodeFeatureProvider: PromptToCodeFeatureProviderKey {
        .init()
    }

    struct PromptToCodeGenerateDescription: UserDefaultPreferenceKey {
        public let defaultValue = true
        public let key = "PromptToCodeGenerateDescription"
    }

    var promptToCodeGenerateDescription: PromptToCodeGenerateDescription { .init() }

    struct PromptToCodeGenerateDescriptionInUserPreferredLanguage: UserDefaultPreferenceKey {
        public let defaultValue = true
        public let key = "PromptToCodeGenerateDescriptionInUserPreferredLanguage"
    }

    var promptToCodeGenerateDescriptionInUserPreferredLanguage: PromptToCodeGenerateDescriptionInUserPreferredLanguage {
        .init()
    }
}

// MARK: - Suggestion

public extension UserDefaultPreferenceKeys {
    struct SuggestionFeatureProviderKey: UserDefaultPreferenceKey {
        public let defaultValue: SuggestionFeatureProvider = .gitHubCopilot
        public let key = "SuggestionFeatureProvider"
    }

    var suggestionFeatureProvider: SuggestionFeatureProviderKey { .init() }

    struct RealtimeSuggestionToggle: UserDefaultPreferenceKey {
        public let defaultValue: Bool = true
        public let key = "RealtimeSuggestionToggle"
    }

    var realtimeSuggestionToggle: RealtimeSuggestionToggle { .init() }

    struct SuggestionCodeFontSize: UserDefaultPreferenceKey {
        public let defaultValue = 13 as Double
        public let key = "SuggestionCodeFontSize"
    }

    var suggestionCodeFontSize: SuggestionCodeFontSize { .init() }

    struct DisableSuggestionFeatureGlobally: UserDefaultPreferenceKey {
        public let defaultValue = false
        public let key = "DisableSuggestionFeatureGlobally"
    }

    var disableSuggestionFeatureGlobally: DisableSuggestionFeatureGlobally {
        .init()
    }

    struct SuggestionFeatureEnabledProjectList: UserDefaultPreferenceKey {
        public let defaultValue: [String] = []
        public let key = "SuggestionFeatureEnabledProjectList"
    }

    var suggestionFeatureEnabledProjectList: SuggestionFeatureEnabledProjectList {
        .init()
    }

    struct SuggestionFeatureDisabledLanguageList: UserDefaultPreferenceKey {
        public let defaultValue: [String] = []
        public let key = "SuggestionFeatureDisabledLanguageList"
    }

    var suggestionFeatureDisabledLanguageList: SuggestionFeatureDisabledLanguageList {
        .init()
    }

    struct HideCommonPrecedingSpacesInSuggestion: UserDefaultPreferenceKey {
        public let defaultValue = true
        public let key = "HideCommonPrecedingSpacesInSuggestion"
    }

    var hideCommonPrecedingSpacesInSuggestion: HideCommonPrecedingSpacesInSuggestion {
        .init()
    }

    struct AcceptSuggestionWithAccessibilityAPI: UserDefaultPreferenceKey {
        public let defaultValue = false
        public let key = "AcceptSuggestionWithAccessibilityAPI"
    }

    var acceptSuggestionWithAccessibilityAPI: AcceptSuggestionWithAccessibilityAPI {
        .init()
    }

    struct SuggestionPresentationMode: UserDefaultPreferenceKey {
        public let defaultValue = PresentationMode.floatingWidget
        public let key = "SuggestionPresentationMode"
    }

    var suggestionPresentationMode: SuggestionPresentationMode { .init() }

    struct RealtimeSuggestionDebounce: UserDefaultPreferenceKey {
        public let defaultValue: Double = 1
        public let key = "RealtimeSuggestionDebounce"
    }

    var realtimeSuggestionDebounce: RealtimeSuggestionDebounce { .init() }
}

// MARK: - Chat

public extension UserDefaultPreferenceKeys {
    struct ChatFontSize: UserDefaultPreferenceKey {
        public let defaultValue = 12 as Double
        public let key = "ChatFontSize"
    }

    var chatFontSize: ChatFontSize { .init() }

    struct ChatCodeFontSize: UserDefaultPreferenceKey {
        public let defaultValue = 12 as Double
        public let key = "ChatCodeFontSize"
    }

    var chatCodeFontSize: ChatCodeFontSize { .init() }

    struct UseGlobalChat: UserDefaultPreferenceKey {
        public let defaultValue = true
        public let key = "UseGlobalChat"
    }

    var useGlobalChat: UseGlobalChat { .init() }
}

// MARK: - Custom Commands

public extension UserDefaultPreferenceKeys {
    struct CustomCommandsKey: UserDefaultPreferenceKey {
        public let defaultValue: [CustomCommand] = [
            .init(
                commandId: "BuiltInCustomCommandExplainSelection",
                name: "Explain Selection",
                feature: .chatWithSelection(
                    extraSystemPrompt: nil,
                    prompt: "Explain the code concisely, do not interpret or translate it."
                )
            ),
            .init(
                commandId: "BuiltInCustomCommandAddDocumentationToSelection",
                name: "Add Documentation to Selection",
                feature: .promptToCode(
                    extraSystemPrompt: nil,
                    prompt: "Add documentation on top of the code. Use triple slash if the language supports it.",
                    continuousMode: false
                )
            ),
        ]
        public let key = "CustomCommands"
    }

    var customCommands: CustomCommandsKey { .init() }
}

// MARK: - Feature Flags

public enum FeatureFlags {
    public struct DisableLazyVStack: UserDefaultPreferenceKey {
        public let defaultValue = false
        public let key = "FeatureFlag-DisableLazyVStack"
    }

    public struct PreCacheOnFileOpen: UserDefaultPreferenceKey {
        public let defaultValue = true
        public let key = "FeatureFlag-PreCacheOnFileOpen"
    }

    public struct RunNodeWithInteractiveLoggedInShell: UserDefaultPreferenceKey {
        public let defaultValue = true
        public let key = "FeatureFlag-RunNodeWithInteractiveLoggedInShell"
    }

    public struct UseCustomScrollViewWorkaround: UserDefaultPreferenceKey {
        public let defaultValue = true
        public let key = "FeatureFlag-UseCustomScrollViewWorkaround"
    }

    public struct TriggerActionWithAccessibilityAPI: UserDefaultPreferenceKey {
        public let defaultValue = true
        public let key = "FeatureFlag-TriggerActionWithAccessibilityAPI"
    }
}

public extension UserDefaultPreferenceKeys {
    var disableLazyVStack: FeatureFlags.DisableLazyVStack { .init() }
    var preCacheOnFileOpen: FeatureFlags.PreCacheOnFileOpen { .init() }
    var runNodeWithInteractiveLoggedInShell: FeatureFlags
        .RunNodeWithInteractiveLoggedInShell { .init() }
    var useCustomScrollViewWorkaround: FeatureFlags.UseCustomScrollViewWorkaround { .init() }
    var triggerActionWithAccessibilityAPI: FeatureFlags
        .TriggerActionWithAccessibilityAPI { .init() }
}

