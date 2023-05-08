import Client
import LaunchAgentManager
import Preferences
import SwiftUI

struct GeneralView: View {
    @State var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AppInfoView()
                Divider()
                ExtensionServiceView(errorMessage: $errorMessage)
                Divider()
                LaunchAgentView(errorMessage: $errorMessage)
                Divider()
                GeneralSettingsView()
            }
        }.safeAreaInset(edge: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 8))
                    .padding()
                    .shadow(radius: 10)
            }
        }
    }
}

struct AppInfoView: View {
    @State var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    @Environment(\.updateChecker) var updateChecker

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Text("Copilot For Xcode")
                    .font(.title)
                Text(appVersion ?? "")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    updateChecker.checkForUpdates()
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.right.circle.fill")
                        Text("Check for Updates")
                    }
                }
            }

            HStack(spacing: 16) {
                Link(
                    destination: URL(string: "https://github.com/intitni/CopilotForXcode")!
                ) {
                    HStack(spacing: 2) {
                        Image(systemName: "link")
                        Text("GitHub")
                    }
                }
                .focusable(false)
                .foregroundColor(.accentColor)

                Link(destination: URL(string: "https://www.buymeacoffee.com/intitni")!) {
                    HStack(spacing: 2) {
                        Image(systemName: "cup.and.saucer.fill")
                        Text("Buy Me A Coffee")
                    }
                }
                .foregroundColor(.accentColor)
                .focusable(false)
            }
        }.padding()
    }
}

struct ExtensionServiceView: View {
    @Binding var errorMessage: String?
    @State var xpcServiceVersion: String?
    @State var accessibilityPermissionGranted: Bool?
    @State var isRunningAction = false

    var body: some View {
        VStack(alignment: .leading) {
            Text("Extension Service Version: \(xpcServiceVersion ?? "Loading..")")
            let grantedStatus: String = {
                guard let accessibilityPermissionGranted else { return "Loading.." }
                return accessibilityPermissionGranted ? "Granted" : "Not Granted"
            }()
            Text("Accessibility Permission: \(grantedStatus)")

            HStack {
                Button(action: { checkStatus() }) {
                    Text("Refresh")
                }.disabled(isRunningAction)

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
                    Text("Reveal Extension Service in Finder")
                }
            }
        }
        .padding()
        .onAppear {
            Task {
                let service = try getService()
                xpcServiceVersion = try await service.getXPCServiceVersion().version
            }
        }
    }

    func checkStatus() {
        Task {
            isRunningAction = true
            defer { isRunningAction = false }
            do {
                let service = try getService()
                xpcServiceVersion = try await service.getXPCServiceVersion().version
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct LaunchAgentView: View {
    @Binding var errorMessage: String?
    @State var isDidRemoveLaunchAgentAlertPresented = false
    @State var isDidSetupLaunchAgentAlertPresented = false
    @State var isDidRestartLaunchAgentAlertPresented = false

    var body: some View {
        VStack(alignment: .leading) {
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
            }
        }
        .padding()
    }
}

struct GeneralSettingsView: View {
    class Settings: ObservableObject {
        @AppStorage(\.quitXPCServiceOnXcodeAndAppQuit)
        var quitXPCServiceOnXcodeAndAppQuit
        @AppStorage(\.suggestionWidgetPositionMode)
        var suggestionWidgetPositionMode
        @AppStorage(\.widgetColorScheme)
        var widgetColorScheme
        @AppStorage(\.preferWidgetToStayInsideEditorWhenWidthGreaterThan)
        var preferWidgetToStayInsideEditorWhenWidthGreaterThan
    }

    @StateObject var settings = Settings()
    @Environment(\.updateChecker) var updateChecker

    var body: some View {
        Form {
            Toggle(isOn: $settings.quitXPCServiceOnXcodeAndAppQuit) {
                Text("Quit service when Xcode and host app are terminated")
            }

            Toggle(isOn: .init(
                get: { updateChecker.automaticallyChecksForUpdates },
                set: { updateChecker.automaticallyChecksForUpdates = $0 }
            )) {
                Text("Automatically Check for Update")
            }

            Picker(selection: $settings.widgetColorScheme) {
                ForEach(WidgetColorScheme.allCases, id: \.rawValue) {
                    switch $0 {
                    case .system:
                        Text("System").tag($0)
                    case .light:
                        Text("Light").tag($0)
                    case .dark:
                        Text("Dark").tag($0)
                    }
                }
            } label: {
                Text("Widget color scheme")
            }

            HStack(alignment: .firstTextBaseline) {
                TextField(text: .init(get: {
                    "\(Int(settings.preferWidgetToStayInsideEditorWhenWidthGreaterThan))"
                }, set: {
                    settings
                        .preferWidgetToStayInsideEditorWhenWidthGreaterThan =
                        Double(Int($0) ?? 0)
                })) {
                    Text("Prefer widget to be inside editor\nwhen width greater than")
                        .multilineTextAlignment(.trailing)
                }
                .textFieldStyle(.roundedBorder)

                Text("pt")
            }
        }.padding()
    }
}

struct GeneralView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralView()
    }
}

struct GeneralView_ErrorMessage_Previews: PreviewProvider {
    static var previews: some View {
        GeneralView(errorMessage: "Error Message")
    }
}

