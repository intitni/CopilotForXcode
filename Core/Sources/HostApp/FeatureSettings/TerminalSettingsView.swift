import Preferences
import SharedUIComponents
import SwiftUI

#if canImport(ProHostApp)
import ProHostApp
#endif

struct TerminalSettingsView: View {
    class Settings: ObservableObject {
        @AppStorage(\.terminalFont) var terminalFont
        init() {}
    }
    
    @StateObject var settings = Settings()
    
    var body: some View {
        ScrollView {
            Form {
                FontPicker(font: $settings.terminalFont) {
                    Text("Font of code")
                }
            }
        }
                
    }
}
