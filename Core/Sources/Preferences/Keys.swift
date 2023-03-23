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
}
