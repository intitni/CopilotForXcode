import LaunchAgentManager
import SwiftUI
import XPCShared

struct LaunchAgentView: View {
    @State var errorMessage: String?
    @State var isDidRemoveLaunchAgentAlertPresented = false
    @State var isDidSetupLaunchAgentAlertPresented = false
    @State var isDidRestartLaunchAgentAlertPresented = false
    @AppStorage(SettingsKey.nodePath, store: .shared) var nodePath: String = ""

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button(action: {
                        do {
                            try LaunchAgentManager().setupLaunchAgent()
                            isDidSetupLaunchAgentAlertPresented = true
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }) {
                        Text("Set Up Launch Agent for XPC Service")
                    }
                    .alert(isPresented: $isDidSetupLaunchAgentAlertPresented) {
                        .init(
                            title: Text("Finished Launch Agent Setup"),
                            message: Text(
                                "You may need to restart Xcode to make the extension work."
                            ),
                            dismissButton: .default(Text("OK"))
                        )
                    }

                    Button(action: {
                        do {
                            try LaunchAgentManager().removeLaunchAgent()
                            isDidRemoveLaunchAgentAlertPresented = true
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }) {
                        Text("Remove Launch Agent")
                    }
                    .alert(isPresented: $isDidRemoveLaunchAgentAlertPresented) {
                        .init(
                            title: Text("Launch Agent Removed"),
                            dismissButton: .default(Text("OK"))
                        )
                    }

                    Button(action: {
                        LaunchAgentManager().restartLaunchAgent()
                        isDidRestartLaunchAgentAlertPresented = true
                    }) {
                        Text("Restart XPC Service")
                    }.alert(isPresented: $isDidRestartLaunchAgentAlertPresented) {
                        .init(
                            title: Text("Launch Agent Restarted"),
                            dismissButton: .default(Text("OK"))
                        )
                    }

                    EmptyView()
                        .alert(isPresented: .init(
                            get: { errorMessage != nil },
                            set: { yes in
                                if !yes { errorMessage = nil }
                            }
                        )) {
                            .init(
                                title: Text("Failed. Got to the GitHub page for Help"),
                                message: Text(errorMessage ?? "Unknown Error"),
                                dismissButton: .default(Text("OK"))
                            )
                        }
                }

                HStack {
                    Text("Path to Node: ")
                    TextField("node", text: $nodePath)
                        .textFieldStyle(.copilot)
                }
            }
        }.buttonStyle(.copilot)
    }
}

struct LaunchAgentView_Preview: PreviewProvider {
    static var previews: some View {
        LaunchAgentView()
            .background(.black)
    }
}
