import Preferences
import SwiftUI

struct SuggestionSettingsView: View {
    final class Settings: ObservableObject {
        @AppStorage(\.realtimeSuggestionToggle)
        var realtimeSuggestionToggle
        @AppStorage(\.realtimeSuggestionDebounce)
        var realtimeSuggestionDebounce
        @AppStorage(\.suggestionPresentationMode)
        var suggestionPresentationMode
        @AppStorage(\.acceptSuggestionWithAccessibilityAPI)
        var acceptSuggestionWithAccessibilityAPI
        @AppStorage(\.disableSuggestionFeatureGlobally)
        var disableSuggestionFeatureGlobally
        @AppStorage(\.suggestionFeatureEnabledProjectList)
        var suggestionFeatureEnabledProjectList
        @AppStorage(\.hideCommonPrecedingSpacesInSuggestion)
        var hideCommonPrecedingSpacesInSuggestion
        @AppStorage(\.suggestionCodeFontSize)
        var suggestionCodeFontSize
        @AppStorage(\.suggestionFeatureProvider)
        var suggestionFeatureProvider
        init() {}
    }

    @StateObject var settings = Settings()
    @State var isSuggestionFeatureEnabledListPickerOpen = false
    @State var isSuggestionFeatureDisabledLanguageListViewOpen = false

    var body: some View {
        Form {
            Group {
                Picker(selection: $settings.suggestionPresentationMode) {
                    ForEach(PresentationMode.allCases, id: \.rawValue) {
                        switch $0 {
                        case .comment:
                            Text("Comment (Deprecating Soon)").tag($0)
                        case .floatingWidget:
                            Text("Floating Widget").tag($0)
                        }
                    }
                } label: {
                    Text("Presentation")
                }

                Picker(selection: $settings.suggestionFeatureProvider) {
                    ForEach(SuggestionFeatureProvider.allCases, id: \.rawValue) {
                        switch $0 {
                        case .gitHubCopilot:
                            Text("GitHub Copilot").tag($0)
                        case .codeium:
                            Text("Codeium").tag($0)
                        }
                    }
                } label: {
                    Text("Feature Provider")
                }

                Toggle(isOn: $settings.realtimeSuggestionToggle) {
                    Text("Real-time suggestion")
                }

                HStack {
                    Toggle(isOn: $settings.disableSuggestionFeatureGlobally) {
                        Text("Disable Suggestion Feature Globally")
                    }

                    Button("Exception List") {
                        isSuggestionFeatureEnabledListPickerOpen = true
                    }
                }.sheet(isPresented: $isSuggestionFeatureEnabledListPickerOpen) {
                    SuggestionFeatureEnabledProjectListView(
                        isOpen: $isSuggestionFeatureEnabledListPickerOpen
                    )
                }
                
                HStack {
                    Button("Disabled Language List") {
                        isSuggestionFeatureDisabledLanguageListViewOpen = true
                    }
                }.sheet(isPresented: $isSuggestionFeatureDisabledLanguageListViewOpen) {
                    SuggestionFeatureDisabledLanguageListView(
                        isOpen: $isSuggestionFeatureDisabledLanguageListViewOpen
                    )
                }

                HStack {
                    Slider(value: $settings.realtimeSuggestionDebounce, in: 0...2, step: 0.1) {
                        Text("Real-time Suggestion Debounce")
                    }

                    Text(
                        "\(settings.realtimeSuggestionDebounce.formatted(.number.precision(.fractionLength(2))))s"
                    )
                    .font(.body)
                    .monospacedDigit()
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.primary.opacity(0.1))
                    )
                }

                Divider()
            }

            Group {
                Toggle(isOn: $settings.hideCommonPrecedingSpacesInSuggestion) {
                    Text("Hide Common Preceding Spaces")
                }

                HStack {
                    TextField(text: .init(get: {
                        "\(Int(settings.suggestionCodeFontSize))"
                    }, set: {
                        settings.suggestionCodeFontSize = Double(Int($0) ?? 0)
                    })) {
                        Text("Font size of suggestion code")
                    }
                    .textFieldStyle(.roundedBorder)

                    Text("pt")
                }
                Divider()
            }

            Group {
                Toggle(isOn: $settings.acceptSuggestionWithAccessibilityAPI) {
                    Text("Use accessibility API to accept suggestion in widget")
                }

                Text("You can turn it on if the accept button is not working for you.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SuggestionSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SuggestionSettingsView()
    }
}

