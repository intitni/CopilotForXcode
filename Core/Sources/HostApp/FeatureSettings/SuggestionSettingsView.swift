import Client
import Preferences
import SharedUIComponents
import SwiftUI
import XPCShared

#if canImport(ProHostApp)
import ProHostApp
#endif

struct SuggestionSettingsView: View {
    final class Settings: ObservableObject {
        @AppStorage(\.realtimeSuggestionToggle)
        var realtimeSuggestionToggle
        @AppStorage(\.realtimeSuggestionDebounce)
        var realtimeSuggestionDebounce
        @AppStorage(\.suggestionPresentationMode)
        var suggestionPresentationMode
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
        @AppStorage(\.suggestionDisplayCompactMode)
        var suggestionDisplayCompactMode
        @AppStorage(\.acceptSuggestionWithTab)
        var acceptSuggestionWithTab
        @AppStorage(\.isSuggestionSenseEnabled)
        var isSuggestionSenseEnabled

        var refreshExtensionSuggestionFeatureProvidersTask: Task<Void, Never>?

        @MainActor
        @Published var extensionSuggestionFeatureProviders = [ExtensionSuggestionFeatureProvider]()

        init() {
            Task { @MainActor in
                refreshExtensionSuggestionFeatureProviders()
            }
            refreshExtensionSuggestionFeatureProvidersTask = Task { [weak self] in
                let sequence = await NotificationCenter.default
                    .notifications(named: NSApplication.didBecomeActiveNotification)
                for await _ in sequence {
                    guard let self else { return }
                    await MainActor.run {
                        self.refreshExtensionSuggestionFeatureProviders()
                    }
                }
            }
        }

        struct ExtensionSuggestionFeatureProvider: Identifiable {
            var id: String { bundleIdentifier }
            var name: String
            var bundleIdentifier: String
        }

        @MainActor
        func refreshExtensionSuggestionFeatureProviders() {
            guard let service = try? getService() else { return }
            Task { @MainActor in
                let services = try await service
                    .send(requestBody: ExtensionServiceRequests.GetExtensionSuggestionServices())
                extensionSuggestionFeatureProviders = services.map {
                    .init(name: $0.name, bundleIdentifier: $0.bundleIdentifier)
                }
            }
        }
    }

    @StateObject var settings = Settings()
    @State var isSuggestionFeatureEnabledListPickerOpen = false
    @State var isSuggestionFeatureDisabledLanguageListViewOpen = false

    var body: some View {
        Form {
            Picker(selection: $settings.suggestionPresentationMode) {
                ForEach(PresentationMode.allCases, id: \.rawValue) {
                    switch $0 {
                    case .nearbyTextCursor:
                        Text("Nearby Text Cursor").tag($0)
                    case .floatingWidget:
                        Text("Floating Widget").tag($0)
                    }
                }
            } label: {
                Text("Presentation")
            }

            Picker(selection: $settings.suggestionFeatureProvider) {
                ForEach(BuiltInSuggestionFeatureProvider.allCases, id: \.rawValue) {
                    switch $0 {
                    case .gitHubCopilot:
                        Text("GitHub Copilot").tag(SuggestionFeatureProvider.builtIn($0))
                    case .codeium:
                        Text("Codeium").tag(SuggestionFeatureProvider.builtIn($0))
                    }
                }

                ForEach(settings.extensionSuggestionFeatureProviders, id: \.id) {
                    Text($0.name).tag(SuggestionFeatureProvider.extension(
                        name: $0.name,
                        bundleIdentifier: $0.bundleIdentifier
                    ))
                }
            } label: {
                Text("Feature Provider")
            }

            Toggle(isOn: $settings.realtimeSuggestionToggle) {
                Text("Real-time Suggestion")
            }

            #if canImport(ProHostApp)
            WithFeatureEnabled(\.suggestionSense) {
                Toggle(isOn: $settings.isSuggestionSenseEnabled) {
                    Text("Suggestion Cheatsheet (Experimental)")
                }
            }
            #endif

            #if canImport(ProHostApp)
            WithFeatureEnabled(\.tabToAcceptSuggestion) {
                Toggle(isOn: $settings.acceptSuggestionWithTab) {
                    Text("Accept Suggestion with Tab")
                }
            }
            #endif

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
        }

        SettingsDivider("UI")

        Form {
            Toggle(isOn: $settings.suggestionDisplayCompactMode) {
                Text("Hide Buttons")
            }

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
        }
    }
}

struct SuggestionSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SuggestionSettingsView()
    }
}

