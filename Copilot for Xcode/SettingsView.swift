import LaunchAgentManager
import SwiftUI
import XPCShared

struct SettingsView: View {
    @AppStorage(SettingsKey.quitXPCServiceOnXcodeAndAppQuit, store: .shared)
    var quitXPCServiceOnXcodeAndAppQuit: Bool = false
    @AppStorage(SettingsKey.realtimeSuggestionToggle, store: .shared)
    var realtimeSuggestionToggle: Bool = false
    @AppStorage(SettingsKey.realtimeSuggestionDebounce, store: .shared)
    var realtimeSuggestionDebounce: Double = 0.7
    @AppStorage(SettingsKey.suggestionPresentationMode, store: .shared)
    var suggestionPresentationModeRawValue: Int = 0
    @State var editingRealtimeSuggestionDebounce: Double = UserDefaults.shared
        .value(forKey: SettingsKey.realtimeSuggestionDebounce) as? Double ?? 0.7

    var body: some View {
        Section {
            Form {
                Toggle(isOn: $quitXPCServiceOnXcodeAndAppQuit) {
                    Text("Quit service when Xcode and host app are terminated")
                }
                .toggleStyle(.switch)

                Picker(selection: $suggestionPresentationModeRawValue) {
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
                
                Toggle(isOn: $realtimeSuggestionToggle) {
                    Text("Real-time suggestion")
                }
                .toggleStyle(.switch)

                HStack {
                    Slider(value: $editingRealtimeSuggestionDebounce, in: 0...2, step: 0.1) {
                        Text("Real-time suggestion fetch debounce")
                    } onEditingChanged: { _ in
                        realtimeSuggestionDebounce = editingRealtimeSuggestionDebounce
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
