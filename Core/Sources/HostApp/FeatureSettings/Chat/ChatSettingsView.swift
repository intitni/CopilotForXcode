import Preferences
import SharedUIComponents
import SwiftUI

struct ChatSettingsView: View {
    enum Tab {
        case general
        case scopes
    }
    
    @State var tabSelection: Tab = .general
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tabSelection) {
                Text("General").tag(Tab.general)
                Text("Scopes").tag(Tab.scopes)
            }
            .pickerStyle(.segmented)
            .padding(8)
            
            Divider()
                .shadow(radius: 10)
            
            ScrollView {
                Group {
                    switch tabSelection {
                    case .general:
                        ChatSettingsGeneralSectionView()
                    case .scopes:
                        ChatSettingsScopeSectionView()
                    }
                }.padding()
            }
        }
    }
}

#Preview {
    ChatSettingsView()
        .frame(width: 600, height: 500)
}
