import AppKit
import SuggestionModel
import SwiftUI

struct ContentView: View {
    @Environment(\.openURL) var openURL
    @AppStorage("username") var username: String = ""
    @State var copilotStatus: GitHubCopilotAccountStatus?
    @State var message: String?
    @State var userCode: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                AppInfoView()
                LaunchAgentView()
                AccountView()
                SettingsView()
                InstructionView()
                DebugSettingsView()
                Spacer()
            }
            .padding(.all, 12)
        }
        .background(LinearGradient(
            colors: [Color("BackgroundColorTop"), Color("BackgroundColor")],
            startPoint: .topLeading,
            endPoint: .bottom
        ))
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [Color("BackgroundColorTop"), Color("BackgroundColorTop").opacity(0)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 44)
            .ignoresSafeArea()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(height: 1200)
    }
}
