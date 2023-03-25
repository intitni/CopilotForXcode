import LaunchAgentManager
import Preferences
import SwiftUI

final class DebugSettings: ObservableObject {
    @AppStorage(\.disableLazyVStack)
    var disableLazyVStack: Bool
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
            }
        }.buttonStyle(.copilot)
    }
}

struct DebugSettingsView_Preview: PreviewProvider {
    static var previews: some View {
        DebugSettingsView()
            .background(.purple)
    }
}
