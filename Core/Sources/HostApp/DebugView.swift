import Preferences
import SwiftUI

final class DebugSettings: ObservableObject {
    @AppStorage(\.animationACrashSuggestion) var animationACrashSuggestion
    @AppStorage(\.animationBCrashSuggestion) var animationBCrashSuggestion
    @AppStorage(\.animationCCrashSuggestion) var animationCCrashSuggestion
    @AppStorage(\.preCacheOnFileOpen) var preCacheOnFileOpen
    @AppStorage(\.useCustomScrollViewWorkaround) var useCustomScrollViewWorkaround
    @AppStorage(\.triggerActionWithAccessibilityAPI) var triggerActionWithAccessibilityAPI
    @AppStorage(\.alwaysAcceptSuggestionWithAccessibilityAPI)
    var alwaysAcceptSuggestionWithAccessibilityAPI
    @AppStorage(\.enableXcodeInspectorDebugMenu) var enableXcodeInspectorDebugMenu
    init() {}
}

struct DebugSettingsView: View {
    @StateObject var settings = DebugSettings()

    var body: some View {
        ScrollView {
            Form {
                Toggle(isOn: $settings.animationACrashSuggestion) {
                    Text("Enable Animation A")
                }
                Toggle(isOn: $settings.animationBCrashSuggestion) {
                    Text("Enable Animation B")
                }
                Toggle(isOn: $settings.animationCCrashSuggestion) {
                    Text("Enable Widget Breathing Animation")
                }
                Toggle(isOn: $settings.preCacheOnFileOpen) {
                    Text("Cache editor information on file open")
                }
                Toggle(isOn: $settings.useCustomScrollViewWorkaround) {
                    Text("Use custom scroll view workaround for smooth scrolling")
                }
                Toggle(isOn: $settings.triggerActionWithAccessibilityAPI) {
                    Text("Trigger command with AccessibilityAPI")
                }
                Toggle(isOn: $settings.alwaysAcceptSuggestionWithAccessibilityAPI) {
                    Text("Always accept suggestion with AccessibilityAPI")
                }
                Toggle(isOn: $settings.enableXcodeInspectorDebugMenu) {
                    Text("Enable Xcode inspector debug menu")
                }
            }
            .padding()
        }
    }
}

struct DebugSettingsView_Preview: PreviewProvider {
    static var previews: some View {
        DebugSettingsView()
    }
}

