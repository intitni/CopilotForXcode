import Foundation

public extension UserDefaults {
    static var shared = UserDefaults(suiteName: "5YKZ4Y3DAW.group.com.intii.CopilotForXcode")!

    static func setupDefaultSettings() {
        func setDefaultValue<T>(_ value: T, forKey: String) {
            let userDefaults = UserDefaults.shared
            if userDefaults.value(forKey: forKey) == nil {
                userDefaults.set(value, forKey: forKey)
            }
        }
        setDefaultValue(true, forKey: SettingsKey.quitXPCServiceOnXcodeAndAppQuit)
        setDefaultValue(false, forKey: SettingsKey.realtimeSuggestionToggle)
        setDefaultValue(1 as Double, forKey: SettingsKey.realtimeSuggestionDebounce)
        setDefaultValue(false, forKey: SettingsKey.automaticallyCheckForUpdate)
    }
}

public enum SettingsKey {
    public static let nodePath = "NodePath"
    public static let realtimeSuggestionToggle = "RealtimeSuggestionToggle"
    public static let realtimeSuggestionDebounce = "RealtimeSuggestionDebounce"
    public static let quitXPCServiceOnXcodeAndAppQuit = "QuitXPCServiceOnXcodeAndAppQuit"
    public static let suggestionPresentationMode = "SuggestionPresentationMode"
    public static let automaticallyCheckForUpdate = "AutomaticallyCheckForUpdate"
    public static let suggestionWidgetPositionMode = "SuggestionWidgetPositionMode"
}
