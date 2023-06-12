import LaunchAgentManager
import Preferences
import SwiftUI

final class Settings: ObservableObject {
    @AppStorage(\.quitXPCServiceOnXcodeAndAppQuit)
    var quitXPCServiceOnXcodeAndAppQuit: Bool
    @AppStorage(\.realtimeSuggestionToggle)
    var realtimeSuggestionToggle: Bool
    @AppStorage(\.realtimeSuggestionDebounce)
    var realtimeSuggestionDebounce: Double
    @AppStorage(\.suggestionPresentationMode)
    var suggestionPresentationMode: Preferences.PresentationMode
    @AppStorage(\.suggestionWidgetPositionMode)
    var suggestionWidgetPositionMode: SuggestionWidgetPositionMode
    @AppStorage(\.widgetColorScheme)
    var widgetColorScheme: WidgetColorScheme
    @AppStorage(\.acceptSuggestionWithAccessibilityAPI)
    var acceptSuggestionWithAccessibilityAPI: Bool
    init() {}
}

struct SettingsView: View {
    @StateObject var settings = Settings()
    @State var editingRealtimeSuggestionDebounce: Double = UserDefaults.shared
        .value(for: \.realtimeSuggestionDebounce)
    @Environment(\.updateChecker) var updateChecker
    @AppStorage(\.codeFontSize) var codeFontSize: String

    var body: some View {
        Section {
            Form {
                Toggle(isOn: $settings.quitXPCServiceOnXcodeAndAppQuit) {
                    Text("Quit service when Xcode and host app are terminated")
                }
                .toggleStyle(.switch)

                Toggle(isOn: .init(
                    get: { updateChecker.automaticallyChecksForUpdates },
                    set: { updateChecker.automaticallyChecksForUpdates = $0 }
                )) {
                    Text("Automatically Check for Update")
                }
                .toggleStyle(.switch)

                Picker(selection: $settings.suggestionPresentationMode) {
                    ForEach(PresentationMode.allCases, id: \.rawValue) {
                        switch $0 {
                        case .comment:
                            Text("Comment").tag($0)
                        case .floatingWidget:
                            Text("Floating Widget").tag($0)
                        }
                    }
                } label: {
                    Text("Present suggestions in")
                }

                if settings.suggestionPresentationMode == PresentationMode.floatingWidget {
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
                }

                Toggle(isOn: $settings.realtimeSuggestionToggle) {
                    Text("Real-time suggestion")
                }
                .toggleStyle(.switch)

                HStack {
                    Slider(value: $editingRealtimeSuggestionDebounce, in: 0...2, step: 0.1) {
                        Text("Real-time suggestion fetch debounce")
                    } onEditingChanged: { _ in
                        settings.realtimeSuggestionDebounce = editingRealtimeSuggestionDebounce
                    }

                    Text(
                        "\(editingRealtimeSuggestionDebounce.formatted(.number.precision(.fractionLength(2))))s"
                    )
                    .font(.body)
                    .monospacedDigit()
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white.opacity(0.2))
                    )
                }
                
                Toggle(isOn: $settings.acceptSuggestionWithAccessibilityAPI) {
                    Text("Use accessibility API to accept suggestion in widget")
                }
                .toggleStyle(.switch)
                HStack {
                    Text("SuggestionCodeFontSize")
                    TextField("(default：13)", text: $codeFontSize)
                        .textFieldStyle(.copilot)
                }
            }
        }.buttonStyle(.copilot)
    }
}

struct SettingsView_Preview: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .background(.purple)
    }
}
