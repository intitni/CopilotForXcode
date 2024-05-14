import Client
import Preferences
import SharedUIComponents
import SwiftUI
import XPCShared

#if canImport(ProHostApp)
import ProHostApp
#endif

struct SuggestionSettingsView: View {
    enum Tab {
        case general
        case suggestionCheatsheet
    }
    
    @State var tabSelection: Tab = .general
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tabSelection) {
                Text("General").tag(Tab.general)
                Text("Cheatsheet").tag(Tab.suggestionCheatsheet)
            }
            .pickerStyle(.segmented)
            .padding(8)
            
            Divider()
                .shadow(radius: 10)
            
            ScrollView {
                Group {
                    switch tabSelection {
                    case .general:
                        SuggestionSettingsGeneralSectionView()
                    case .suggestionCheatsheet:
                        SuggestionSettingsCheatsheetSectionView()
                    }
                }.padding()
            }
        }
    }
}

struct SuggestionSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SuggestionSettingsView()
            .frame(width: 600, height: 500)
    }
}

