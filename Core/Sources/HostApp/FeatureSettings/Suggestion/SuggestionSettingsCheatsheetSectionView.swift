import Client
import Preferences
import SharedUIComponents
import SwiftUI
import XPCShared

#if canImport(ProHostApp)
import ProHostApp
#endif

struct SuggestionSettingsCheatsheetSectionView: View {
    final class Settings: ObservableObject {
        @AppStorage(\.isSuggestionSenseEnabled)
        var isSuggestionSenseEnabled
    }
    
    @StateObject var settings = Settings()

    var body: some View {
        #if canImport(ProHostApp)
        WithFeatureEnabled(\.suggestionSense) {
            Toggle(isOn: $settings.isSuggestionSenseEnabled) {
                Text("Enable suggestion cheatsheet (experimental)")
            }
        }
        #endif
    }
}

#Preview {
    SuggestionSettingsCheatsheetSectionView()
        .padding()
}
