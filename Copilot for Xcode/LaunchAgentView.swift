import LaunchAgentManager
import SwiftUI
import Preferences

struct LaunchAgentView: View {
    @State var errorMessage: String?
    @State var isDidRemoveLaunchAgentAlertPresented = false
    @State var isDidSetupLaunchAgentAlertPresented = false
    @State var isDidRestartLaunchAgentAlertPresented = false
    @AppStorage(\.nodePath) var nodePath: String

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
                        Text("Set Up Launch Agent")
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
                                try await LaunchAgentManager().reloadLaunchAgent()
                                isDidRestartLaunchAgentAlertPresented = true
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }) {
                        Text("Reload Launch Agent")
                    }.alert(isPresented: $isDidRestartLaunchAgentAlertPresented) {
                        .init(
                            title: Text("Launch Agent Reloaded"),
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
                
                Text("You may have to restart the helper app to apply the changes. To do so, simply close the helper app by clicking on the menu bar icon that looks like a steer wheel, it will automatically restart as needed.")
                    .foregroundColor(.secondary)

                HStack {
                    Button(action: {
                        Task {
                            let workspace = NSWorkspace.shared
                            let url = Bundle.main.bundleURL
                                .appendingPathComponent("Contents")
                                .appendingPathComponent("Applications")
                                .appendingPathComponent("CopilotForXcodeExtensionService.app")
                            workspace.activateFileViewerSelecting([url])
                        }
                    }) {
                        Text("Reveal Extension App in Finder")
                    }

                    Spacer()
                }
            }
        }
        .buttonStyle(.copilot)
        .onAppear {
            #if DEBUG
            // do not auto install on debug build
            #else
            Task {
                do {
                    try await LaunchAgentManager().setupLaunchAgentForTheFirstTimeIfNeeded()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            #endif
        }
    }
}

struct LaunchAgentView_Preview: PreviewProvider {
    static var previews: some View {
        LaunchAgentView()
            .background(.black)
    }
}
