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
                        Task {
                            do {
                                try await LaunchAgentManager().setupLaunchAgent()
                                isDidSetupLaunchAgentAlertPresented = true
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }) {
                        Text("Set Up Launch Agent for XPC Service")
                    }
                    .alert(isPresented: $isDidSetupLaunchAgentAlertPresented) {
                        .init(
                            title: Text("Finished Launch Agent Setup"),
                            message: Text(
                                "Please refresh the Copilot status. (The first refresh may fail)"
                            ),
                            dismissButton: .default(Text("OK"))
                        )
                    }

                    Button(action: {
                        Task {
                            do {
                                try await LaunchAgentManager().removeLaunchAgent()
                                isDidRemoveLaunchAgentAlertPresented = true
                            } catch {
                                errorMessage = error.localizedDescription
                            }
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
                        Task {
                            do {
                                try await LaunchAgentManager().restartLaunchAgent()
                                isDidRestartLaunchAgentAlertPresented = true
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }) {
                        Text("Restart XPC Service")
                    }.alert(isPresented: $isDidRestartLaunchAgentAlertPresented) {
                        .init(
                            title: Text("Launch Agent Restarted"),
                            dismissButton: .default(Text("OK"))
                        )
                    }

                    Spacer()
                        .alert(isPresented: .init(
                            get: { errorMessage != nil },
                            set: { _ in errorMessage = nil }
                        )) {
                            .init(
                                title: Text("Failed"),
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
