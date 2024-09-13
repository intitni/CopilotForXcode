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
                LaunchAgentView(store: store)
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
    @Perception.Bindable var store: StoreOf<General>

    var body: some View {
        WithPerceptionTracking {
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
            }
            .padding()
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}

struct ExtensionServiceView: View {
    @Perception.Bindable var store: StoreOf<General>

    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading) {
                Text("Extension Service Version: \(store.xpcServiceVersion ?? "Loading..")")

                let grantedStatus: String = {
                    guard let granted = store.isAccessibilityPermissionGranted
                    else { return "Loading.." }
                    return granted ? "Granted" : "Not Granted"
                }()
                Text("Accessibility Permission: \(grantedStatus)")

                HStack {
                    Button(action: { store.send(.reloadStatus) }) {
                        Text("Refresh")
                    }.disabled(store.isReloading)

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
        }
        .padding()
    }
}

struct LaunchAgentView: View {
    @Perception.Bindable var store: StoreOf<General>
    @Environment(\.toast) var toast

    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading) {
                HStack {
                    Button(action: {
                        store.send(.setupLaunchAgentClicked)
                    }) {
                        Text("Setup Launch Agent")
                    }

                    Button(action: {
                        store.send(.removeLaunchAgentClicked)
                    }) {
                        Text("Remove Launch Agent")
                    }

                    Button(action: {
                        store.send(.reloadLaunchAgentClicked)
                    }) {
                        Text("Reload Launch Agent")
                    }
                }
            }
            .padding()
        }
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
    @State var automaticallyCheckForUpdate: Bool?

    var body: some View {
        Form {
            Toggle(isOn: $settings.quitXPCServiceOnXcodeAndAppQuit) {
                Text("Quit service when Xcode and host app are terminated")
            }

            Toggle(isOn: .init(
                get: { automaticallyCheckForUpdate ?? updateChecker.automaticallyChecksForUpdates },
                set: {
                    updateChecker.automaticallyChecksForUpdates = $0
                    automaticallyCheckForUpdate = $0
                }
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
        GeneralView(store: .init(initialState: .init(), reducer: { General() }))
            .frame(height: 800)
    }
}

