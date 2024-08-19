import Client
import Preferences
import SharedUIComponents
import SwiftUI
import XPCShared

struct SuggestionSettingsView: View {
    var tabContainer: ExternalTabContainer {
        ExternalTabContainer.tabContainer(for: "SuggestionSettings")
    }
    
    enum Tab: Hashable {
        case general
        case other(String)
    }
    
    @State var tabSelection: Tab = .general
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tabSelection) {
                Text("General").tag(Tab.general)
                ForEach(tabContainer.tabs, id: \.id) { tab in
                    Text(tab.title).tag(Tab.other(tab.id))
                }
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
                    case let .other(id):
                        tabContainer.tabView(for: id)
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

