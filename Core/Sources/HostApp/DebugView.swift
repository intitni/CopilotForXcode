import Preferences
import SwiftUI

final class DebugSettings: ObservableObject {
    @AppStorage(\.disableLazyVStack) var disableLazyVStack
    @AppStorage(\.preCacheOnFileOpen) var preCacheOnFileOpen
    @AppStorage(\.useCustomScrollViewWorkaround) var useCustomScrollViewWorkaround
    @AppStorage(\.triggerActionWithAccessibilityAPI) var triggerActionWithAccessibilityAPI
    init() {}
}

struct DebugSettingsView: View {
    @StateObject var settings = DebugSettings()

    var body: some View {
        ScrollView {
            Form {
                Toggle(isOn: $settings.disableLazyVStack) {
                    Text("Disable LazyVStack")
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

