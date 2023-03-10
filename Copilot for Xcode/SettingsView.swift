import LaunchAgentManager
import SwiftUI
import XPCShared

final class Settings: ObservableObject {
    @AppStorage(SettingsKey.quitXPCServiceOnXcodeAndAppQuit, store: .shared)
    var quitXPCServiceOnXcodeAndAppQuit: Bool = false
    @AppStorage(SettingsKey.realtimeSuggestionToggle, store: .shared)
    var realtimeSuggestionToggle: Bool = false
    @AppStorage(SettingsKey.realtimeSuggestionDebounce, store: .shared)
    var realtimeSuggestionDebounce: Double = 0.7
    @AppStorage(SettingsKey.suggestionPresentationMode, store: .shared)
    var suggestionPresentationModeRawValue: Int = 0
    @AppStorage(SettingsKey.automaticallyCheckForUpdate, store: .shared)
    var automaticallyCheckForUpdate: Bool = false
    @AppStorage(SettingsKey.suggestionWidgetPositionMode, store: .shared)
    var suggestionWidgetPositionModeRawValue: Int = 0
    init() {}
}

struct SettingsView: View {
    @StateObject var settings = Settings()
    @State var editingRealtimeSuggestionDebounce: Double = UserDefaults.shared
        .value(forKey: SettingsKey.realtimeSuggestionDebounce) as? Double ?? 0.7

    var body: some View {
        Section {
            Form {
                Toggle(isOn: $settings.quitXPCServiceOnXcodeAndAppQuit) {
                    Text("Quit service when Xcode and host app are terminated")
                }
                .toggleStyle(.switch)

                Toggle(isOn: $settings.automaticallyCheckForUpdate) {
                    Text("Automatically Check for Update")
                }
                .toggleStyle(.switch)

                Picker(selection: $settings.suggestionPresentationModeRawValue) {
                    ForEach(PresentationMode.allCases, id: \.rawValue) {
                        switch $0 {
                        case .comment:
                            Text("Comment")
                        case .floatingWidget:
                            Text("Floating Widget")
                        }
                    }
                } label: {
                    Text("Present suggestions in")
                }

                if settings.suggestionPresentationModeRawValue == PresentationMode.floatingWidget
                    .rawValue
                {
                    Picker(selection: $settings.suggestionWidgetPositionModeRawValue) {
                        ForEach(SuggestionWidgetPositionMode.allCases, id: \.rawValue) {
                            switch $0 {
                            case .fixedToBottom:
                                Text("Fixed to Bottom")
                            case .alignToTextCursor:
                                Text("Follow Text Cursor")
                            }
                        }
                    } label: {
                        Text("Widget position")
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
