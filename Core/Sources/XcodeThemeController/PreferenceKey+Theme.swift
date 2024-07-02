import Foundation
import Preferences

// MARK: - Theming

public extension UserDefaultPreferenceKeys {
    var lightXcodeThemeName: PreferenceKey<String> {
        .init(defaultValue: "", key: "LightXcodeThemeName")
    }
    
    var lightXcodeTheme: PreferenceKey<UserDefaultsStorageBox<XcodeTheme?>> {
        .init(defaultValue: .init(nil), key: "LightXcodeTheme")
    }
    
    var darkXcodeThemeName: PreferenceKey<String> {
        .init(defaultValue: "", key: "DarkXcodeThemeName")
    }
    
    var darkXcodeTheme: PreferenceKey<UserDefaultsStorageBox<XcodeTheme?>> {
        .init(defaultValue: .init(nil), key: "LightXcodeTheme")
    }

    var lastSyncedHighlightJSThemeCreatedAt: PreferenceKey<TimeInterval> {
        .init(defaultValue: 0, key: "LastSyncedHighlightJSThemeCreatedAt")
    }
}

