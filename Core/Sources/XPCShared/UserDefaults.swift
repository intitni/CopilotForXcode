import Foundation

public extension UserDefaults {
    static var shared = UserDefaults(suiteName: "5YKZ4Y3DAW.group.com.intii.CopilotForXcode")!
}

public enum SettingsKey {
    public static let nodePath = "NodePath"
    public static let realtimeSuggestionToggle = "RealtimeSuggestionToggle"
    public static let realtimeSuggestionDebounce = "RealtimeSuggestionDebounce"
    public static let quitXPCServiceOnXcodeAndAppQuit = "QuitXPCServiceOnXcodeAndAppQuit"
}
