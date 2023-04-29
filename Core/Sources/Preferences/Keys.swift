import Foundation

public protocol UserDefaultPreferenceKey {
    associatedtype Value
    var defaultValue: Value { get }
    var key: String { get }
}

public struct UserDefaultPreferenceKeys {
    public init() {}

    // MARK: - Node Path

    public struct NodePath: UserDefaultPreferenceKey {
        public let defaultValue: String = ""
        public let key = "NodePath"
    }

    public var nodePath: NodePath { .init() }

    // MARK: - Run Node With
    
    public struct RunNodeWithKey: UserDefaultPreferenceKey {
        public let defaultValue = NodeRunner.bash
        public let key = "RunNodeWith"
    }
    
    public var runNodeWith: RunNodeWithKey { .init() }
    
    // MARK: - Realtime Suggestion

    public struct RealtimeSuggestionToggle: UserDefaultPreferenceKey {
        public let defaultValue: Bool = true
        public let key = "RealtimeSuggestionToggle"
    }

    public var realtimeSuggestionToggle: RealtimeSuggestionToggle { .init() }

    // MARK: - Realtime Suggestion Debounce

    public struct RealtimeSuggestionDebounce: UserDefaultPreferenceKey {
        public let defaultValue: Double = 1
        public let key = "RealtimeSuggestionDebounce"
    }

    public var realtimeSuggestionDebounce: RealtimeSuggestionDebounce { .init() }

    // MARK: - Quit XPC Service On Xcode And App Quit

    public struct QuitXPCServiceOnXcodeAndAppQuit: UserDefaultPreferenceKey {
        public let defaultValue = true
        public let key = "QuitXPCServiceOnXcodeAndAppQuit"
    }

    public var quitXPCServiceOnXcodeAndAppQuit: QuitXPCServiceOnXcodeAndAppQuit { .init() }

    // MARK: - Suggestion Presentation Mode

    public struct SuggestionPresentationMode: UserDefaultPreferenceKey {
        public let defaultValue = PresentationMode.floatingWidget
        public let key = "SuggestionPresentationMode"
    }

    public var suggestionPresentationMode: SuggestionPresentationMode { .init() }

    // MARK: - Automatically Check For Update

    public struct AutomaticallyCheckForUpdate: UserDefaultPreferenceKey {
        public let defaultValue = false
        public let key = "AutomaticallyCheckForUpdate"
    }

    public var automaticallyCheckForUpdate: AutomaticallyCheckForUpdate { .init() }

    // MARK: - Suggestion Widget Position Mode

    public struct SuggestionWidgetPositionModeKey: UserDefaultPreferenceKey {
        public let defaultValue = SuggestionWidgetPositionMode.fixedToBottom
        public let key = "SuggestionWidgetPositionMode"
    }

    public var suggestionWidgetPositionMode: SuggestionWidgetPositionModeKey { .init() }

    // MARK: - Widget Color Scheme

    public struct WidgetColorSchemeKey: UserDefaultPreferenceKey {
        public let defaultValue = WidgetColorScheme.dark
        public let key = "WidgetColorScheme"
    }

    public var widgetColorScheme: WidgetColorSchemeKey { .init() }

    // MARK: - Accept Suggestion with Accessibility API

    public struct AcceptSuggestionWithAccessibilityAPI: UserDefaultPreferenceKey {
        public let defaultValue = false
        public let key = "AcceptSuggestionWithAccessibilityAPI"
    }

    public var acceptSuggestionWithAccessibilityAPI: AcceptSuggestionWithAccessibilityAPI {
        .init()
    }

    // MARK: - Use Global Chat

    public struct UseGlobalChat: UserDefaultPreferenceKey {
        public let defaultValue = false
        public let key = "UseGlobalChat"
    }

    public var useGlobalChat: UseGlobalChat { .init() }

    // MARK: - Hide Common Preceding Spaces in Suggestion

    public struct HideCommonPrecedingSpacesInSuggestion: UserDefaultPreferenceKey {
        public let defaultValue = false
        public let key = "HideCommonPrecedingSpacesInSuggestion"
    }

    public var hideCommonPrecedingSpacesInSuggestion: HideCommonPrecedingSpacesInSuggestion {
        .init()
    }

    // MARK: - Force Order Widget to Front

    public struct ForceOrderWidgetToFront: UserDefaultPreferenceKey {
        public let defaultValue = true
        public let key = "ForceOrderWidgetToFront"
    }

    public var forceOrderWidgetToFront: HideCommonPrecedingSpacesInSuggestion {
        .init()
    }

    // MARK: - Disable Suggestion Feature Globally

    public struct DisableSuggestionFeatureGlobally: UserDefaultPreferenceKey {
        public let defaultValue = false
        public let key = "DisableSuggestionFeatureGlobally"
    }

    public var disableSuggestionFeatureGlobally: DisableSuggestionFeatureGlobally {
        .init()
    }

    // MARK: - Suggestion Feature Enabled Project List

    public struct SuggestionFeatureEnabledProjectList: UserDefaultPreferenceKey {
        public let defaultValue: [String] = []
        public let key = "SuggestionFeatureEnabledProjectList"
    }

    public var suggestionFeatureEnabledProjectList: SuggestionFeatureEnabledProjectList {
        .init()
    }

    // MARK: - Prompt to Code Feature Provider

    public struct PromptToCodeFeatureProviderKey: UserDefaultPreferenceKey {
        public let defaultValue: PromptToCodeFeatureProvider = .openAI
        public let key = "PromptToCodeFeatureProvider"
    }

    public var promptToCodeFeatureProvider: PromptToCodeFeatureProviderKey {
        .init()
    }

    // MARK: - Prefer Widget to Stay Inside Editor When Width Greater Than

    public struct PreferWidgetToStayInsideEditorWhenWidthGreaterThan: UserDefaultPreferenceKey {
        public let defaultValue = 1400 as Double
        public let key = "PreferWidgetToStayInsideEditorWhenWidthGreaterThan"
    }

    public var preferWidgetToStayInsideEditorWhenWidthGreaterThan: PreferWidgetToStayInsideEditorWhenWidthGreaterThan {
        .init()
    }
    
    // MARK: - Chat Panel in a Separate Window

    public struct ChatPanelInASeparateWindow: UserDefaultPreferenceKey {
        public let defaultValue = true
        public let key = "ChatPanelInASeparateWindow"
    }

    public var chatPanelInASeparateWindow: ChatPanelInASeparateWindow {
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

// MARK: - UI

public extension UserDefaultPreferenceKeys {
    struct SuggestionCodeFontSize: UserDefaultPreferenceKey {
        public let defaultValue = 13 as Double
        public let key = "SuggestionCodeFontSize"
    }

    var suggestionCodeFontSize: SuggestionCodeFontSize { .init() }
    
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
    var triggerActionWithAccessibilityAPI: FeatureFlags.TriggerActionWithAccessibilityAPI { .init() }
}
