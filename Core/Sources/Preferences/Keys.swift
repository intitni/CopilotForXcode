import Foundation

public protocol UserDefaultPreferenceKey {
    associatedtype Value
    var defaultValue: Value { get }
    var key: String { get }
}

public struct UserDefaultPreferenceKeys {
    public init() {}

    public struct NodePath: UserDefaultPreferenceKey {
        public let defaultValue: String = ""
        public let key = "NodePath"
    }

    public var nodePath: NodePath { .init() }

    public struct RealtimeSuggestionToggle: UserDefaultPreferenceKey {
        public let defaultValue: Bool = false
        public let key = "RealtimeSuggestionToggle"
    }

    public var realtimeSuggestionToggle: RealtimeSuggestionToggle { .init() }

    public struct RealtimeSuggestionDebounce: UserDefaultPreferenceKey {
        public let defaultValue: Double = 1
        public let key = "RealtimeSuggestionDebounce"
    }

    public var realtimeSuggestionDebounce: RealtimeSuggestionDebounce { .init() }

    public struct QuitXPCServiceOnXcodeAndAppQuit: UserDefaultPreferenceKey {
        public let defaultValue = true
        public let key = "QuitXPCServiceOnXcodeAndAppQuit"
    }

    public var quitXPCServiceOnXcodeAndAppQuit: QuitXPCServiceOnXcodeAndAppQuit { .init() }

    public struct SuggestionPresentationMode: UserDefaultPreferenceKey {
        public let defaultValue = PresentationMode.floatingWidget
        public let key = "SuggestionPresentationMode"
    }

    public var suggestionPresentationMode: SuggestionPresentationMode { .init() }

    public struct AutomaticallyCheckForUpdate: UserDefaultPreferenceKey {
        public let defaultValue = false
        public let key = "AutomaticallyCheckForUpdate"
    }

    public var automaticallyCheckForUpdate: AutomaticallyCheckForUpdate { .init() }

    public struct SuggestionWidgetPositionModeKey: UserDefaultPreferenceKey {
        public let defaultValue = SuggestionWidgetPositionMode.fixedToBottom
        public let key = "SuggestionWidgetPositionMode"
    }

    public var suggestionWidgetPositionMode: SuggestionWidgetPositionModeKey { .init() }

    public struct WidgetColorSchemeKey: UserDefaultPreferenceKey {
        public let defaultValue = WidgetColorScheme.dark
        public let key = "WidgetColorScheme"
    }

    public var widgetColorScheme: WidgetColorSchemeKey { .init() }

    public struct OpenAIAPIKey: UserDefaultPreferenceKey {
        public let defaultValue = ""
        public let key = "OpenAIAPIKey"
    }

    public var openAIAPIKey: OpenAIAPIKey { .init() }

    public struct ChatGPTEndpoint: UserDefaultPreferenceKey {
        public let defaultValue = ""
        public let key = "ChatGPTEndpoint"
    }

    public var chatGPTEndpoint: ChatGPTEndpoint { .init() }

    public struct ChatGPTModel: UserDefaultPreferenceKey {
        public let defaultValue = Preferences.ChatGPTModel.gpt35Turbo.rawValue
        public let key = "ChatGPTModel"
    }

    public var chatGPTModel: ChatGPTModel { .init() }

    public struct ChatGPTMaxToken: UserDefaultPreferenceKey {
        public let defaultValue = 2048
        public let key = "ChatGPTMaxToken"
    }

    public var chatGPTMaxToken: ChatGPTMaxToken { .init() }

    public struct ChatGPTLanguage: UserDefaultPreferenceKey {
        public let defaultValue = ""
        public let key = "ChatGPTLanguage"
    }

    public var chatGPTLanguage: ChatGPTLanguage { .init() }

    public struct AcceptSuggestionWithAccessibilityAPI: UserDefaultPreferenceKey {
        public let defaultValue = false
        public let key = "AcceptSuggestionWithAccessibilityAPI"
    }

    public var acceptSuggestionWithAccessibilityAPI: AcceptSuggestionWithAccessibilityAPI {
        .init()
    }

    public struct UseGlobalChat: UserDefaultPreferenceKey {
        public let defaultValue = false
        public let key = "UseGlobalChat"
    }

    public var useGlobalChat: UseGlobalChat { .init() }

    public struct HideCommonPrecedingSpacesInSuggestion: UserDefaultPreferenceKey {
        public let defaultValue = false
        public let key = "HideCommonPrecedingSpacesInSuggestion"
    }

    public var hideCommonPrecedingSpacesInSuggestion: HideCommonPrecedingSpacesInSuggestion {
        .init()
    }
    
    public struct ForceOrderWidgetToFront: UserDefaultPreferenceKey {
        public let defaultValue = true
        public let key = "ForceOrderWidgetToFront"
    }

    public var forceOrderWidgetToFront: HideCommonPrecedingSpacesInSuggestion {
        .init()
    }

    public var disableLazyVStack: FeatureFlags.DisableLazyVStack { .init() }
    public var preCacheOnFileOpen: FeatureFlags.PreCacheOnFileOpen { .init() }
    
    public struct RealtimeSuggestionCodeFontSize: UserDefaultPreferenceKey {
        public let defaultValue: String = "13"
        public let key = "RealtimeSuggestionCodeFontSize"
    }
    public var codeFontSize: RealtimeSuggestionCodeFontSize { .init() }
}

public enum FeatureFlags {
    public struct DisableLazyVStack: UserDefaultPreferenceKey {
        public let defaultValue = false
        public let key = "FeatureFlag-DisableLazyVStack"
    }
    
    public struct PreCacheOnFileOpen: UserDefaultPreferenceKey {
        public let defaultValue = true
        public let key = "FeatureFlag-PreCacheOnFileOpen"
    }
}
