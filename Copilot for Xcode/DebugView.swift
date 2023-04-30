import LaunchAgentManager
import Preferences
import SwiftUI

final class DebugSettings: ObservableObject {
    @AppStorage(\.disableLazyVStack)
    var disableLazyVStack: Bool
    @AppStorage(\.preCacheOnFileOpen)
    var preCacheOnFileOpen: Bool
    @AppStorage(\.useCustomScrollViewWorkaround) var useCustomScrollViewWorkaround
    @AppStorage(\.triggerActionWithAccessibilityAPI) var triggerActionWithAccessibilityAPI
    init() {}
}

struct DebugSettingsView: View {
    @StateObject var settings = DebugSettings()

    var body: some View {
        Section {
            Form {
                Toggle(isOn: $settings.disableLazyVStack) {
                    Text("Disable LazyVStack")
                }
                .toggleStyle(.switch)
                Toggle(isOn: $settings.preCacheOnFileOpen) {
                    Text("Cache editor information on file open")
                }
                .toggleStyle(.switch)
                Toggle(isOn: $settings.useCustomScrollViewWorkaround) {
                    Text("Use custom scroll view workaround for smooth scrolling")
                }
                .toggleStyle(.switch)
                Toggle(isOn: $settings.triggerActionWithAccessibilityAPI) {
                    Text("Trigger action with AccessibilityAPI")
                }
                .toggleStyle(.switch)
            }
        }
        .buttonStyle(.copilot)
    }
}

struct DebugSettingsView_Preview: PreviewProvider {
    static var previews: some View {
        DebugSettingsView()
            .background(.purple)
    }
}
