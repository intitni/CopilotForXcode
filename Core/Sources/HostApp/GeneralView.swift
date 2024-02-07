import Client
import ComposableArchitecture
import KeyboardShortcuts
import LaunchAgentManager
import Preferences
import SharedUIComponents
import SwiftUI

struct GeneralView: View {
    let store: StoreOf<General>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AppInfoView(store: store)
                SettingsDivider()
                ExtensionServiceView(store: store)
                SettingsDivider()
                LaunchAgentView()
                SettingsDivider()
                GeneralSettingsView()
            }
        }
        .onAppear {
            store.send(.appear)
        }
    }
}

struct AppInfoView: View {
    @State var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    @Environment(\.updateChecker) var updateChecker
    let store: StoreOf<General>

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Text(
                    Bundle.main
                        .object(forInfoDictionaryKey: "HOST_APP_NAME") as? String
                        ?? "Copilot for Xcode"
                )
                .font(.title)
                Text(appVersion ?? "")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Spacer()
                
                Button(action: {
                    store.send(.openExtensionManager)
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "puzzlepiece.extension.fill")
                        Text("Extensions")
                    }
                }

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
    let store: StoreOf<General>

    var body: some View {
        VStack(alignment: .leading) {
            WithViewStore(store, observe: { $0.xpcServiceVersion }) { viewStore in
                Text("Extension Service Version: \(viewStore.state ?? "Loading..")")
            }

            WithViewStore(store, observe: { $0.isAccessibilityPermissionGranted }) { viewStore in
                let grantedStatus: String = {
                    guard let granted = viewStore.state else { return "Loading.." }
                    return granted ? "Granted" : "Not Granted"
                }()
                Text("Accessibility Permission: \(grantedStatus)")
            }

            HStack {
                WithViewStore(store, observe: { $0.isReloading }) { viewStore in
                    Button(action: { viewStore.send(.reloadStatus) }) {
                        Text("Refresh")
                    }.disabled(viewStore.state)
                }

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

                Button(action: {
                    let url = URL(
                        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                    )!
                    NSWorkspace.shared.open(url)
                }) {
                    Text("Accessibility Settings")
                }

                Button(action: {
                    let url = URL(
                        string: "x-apple.systempreferences:com.apple.ExtensionsPreferences"
                    )!
                    NSWorkspace.shared.open(url)
                }) {
                    Text("Extensions Settings")
                }
            }
        }
        .padding()
    }
}

struct LaunchAgentView: View {
    @Environment(\.toast) var toast
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
                            toast(error.localizedDescription, .error)
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
                            toast(error.localizedDescription, .error)
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
                            toast(error.localizedDescription, .error)
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
        @AppStorage(\.hideCircularWidget)
        var hideCircularWidget
        @AppStorage(\.showHideWidgetShortcutGlobally)
        var showHideWidgetShortcutGlobally
        @AppStorage(\.installBetaBuilds)
        var installBetaBuilds
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
            
            Toggle(isOn: $settings.installBetaBuilds) {
                Text("Install beta builds")
            }

            Picker(selection: $settings.suggestionWidgetPositionMode) {
                ForEach(SuggestionWidgetPositionMode.allCases, id: \.rawValue) {
                    switch $0 {
                    case .fixedToBottom:
                        Text("Fixed to Bottom").tag($0)
                    case .alignToTextCursor:
                        Text("Follow Text Cursor").tag($0)
                    }
                }
            } label: {
                Text("Widget position")
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

            KeyboardShortcuts.Recorder("Hotkey to Toggle Widgets", name: .showHideWidget) { _ in
                // It's not used in this app!
                KeyboardShortcuts.disable(.showHideWidget)
            }

            Toggle(isOn: $settings.showHideWidgetShortcutGlobally) {
                Text("Enable the Hotkey Globally")
            }

            Toggle(isOn: $settings.hideCircularWidget) {
                Text("Hide circular widget")
            }
        }.padding()
    }
}

struct WidgetPositionIcon: View {
    var position: SuggestionWidgetPositionMode
    var isSelected: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(nsColor: .textBackgroundColor))
            Rectangle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 120, height: 20)
        }
        .frame(width: 120, height: 80)
    }
}

struct LargeIconPicker<
    Data: RandomAccessCollection,
    ID: Hashable,
    Content: View,
    Label: View
>: View {
    @Binding var selection: Data.Element
    var data: Data
    var id: KeyPath<Data.Element, ID>
    var builder: (Data.Element, _ isSelected: Bool) -> Content
    var label: () -> Label

    @ViewBuilder
    var content: some View {
        HStack {
            ForEach(data, id: id) { item in
                let isSelected = selection[keyPath: id] == item[keyPath: id]
                Button(action: {
                    selection = item
                }) {
                    builder(item, isSelected)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    isSelected ? Color.accentColor : Color.primary.opacity(0.1),
                                    style: .init(lineWidth: 2)
                                )
                        }
                }.buttonStyle(.plain)
            }
        }
    }

    var body: some View {
        if #available(macOS 13.0, *) {
            LabeledContent {
                content
            } label: {
                label()
            }
        } else {
            VStack {
                label()
                content
            }
        }
    }
}

struct GeneralView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralView(store: .init(initialState: .init(), reducer: General()))
            .frame(height: 800)
    }
}

