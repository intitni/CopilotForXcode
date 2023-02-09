import AppKit
import CopilotModel
import SwiftUI

struct ContentView: View {
    @Environment(\.openURL) var openURL
    @AppStorage("username") var username: String = ""
    @State var copilotStatus: CopilotStatus?
    @State var message: String?
    @State var userCode: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                AppInfoView()
                LaunchAgentView()
                CopilotView()
                SettingsView()
                InstructionView()
                Spacer()
            }
            .padding(.all, 12)
        }
        .background(LinearGradient(
            colors: [Color("BackgroundColorTop"), Color("BackgroundColor")],
            startPoint: .topLeading,
            endPoint: .bottom
        ))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(height: 800)
    }
}
