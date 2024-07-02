import Client
import Preferences
import SharedUIComponents
import SwiftUI
import XPCShared

#if canImport(ProHostApp)
import ProHostApp
#endif

struct SuggestionSettingsGeneralSectionView: View {
    struct SuggestionFeatureProviderOption: Identifiable, Hashable {
        var id: String {
            (builtInProvider?.rawValue).map(String.init) ?? bundleIdentifier ?? "n/A"
        }

        var name: String
        var builtInProvider: BuiltInSuggestionFeatureProvider?
        var bundleIdentifier: String?

        func hash(into hasher: inout Hasher) {
            id.hash(into: &hasher)
        }

        init(
            name: String,
            builtInProvider: BuiltInSuggestionFeatureProvider? = nil,
            bundleIdentifier: String? = nil
        ) {
            self.name = name
            self.builtInProvider = builtInProvider
            self.bundleIdentifier = bundleIdentifier
        }
    }

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
        @AppStorage(\.suggestionCodeFont)
        var font
        @AppStorage(\.suggestionFeatureProvider)
        var suggestionFeatureProvider
        @AppStorage(\.suggestionDisplayCompactMode)
        var suggestionDisplayCompactMode
        @AppStorage(\.acceptSuggestionWithTab)
        var acceptSuggestionWithTab
        @AppStorage(\.dismissSuggestionWithEsc)
        var dismissSuggestionWithEsc

        var refreshExtensionSuggestionFeatureProvidersTask: Task<Void, Never>?

        @MainActor
        @Published
        var extensionSuggestionFeatureProviderOptions = [SuggestionFeatureProviderOption]()

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

        @MainActor
        func refreshExtensionSuggestionFeatureProviders() {
            guard let service = try? getService() else { return }
            Task { @MainActor in
                let services = try await service
                    .send(requestBody: ExtensionServiceRequests.GetExtensionSuggestionServices())
                extensionSuggestionFeatureProviderOptions = services.map {
                    .init(name: $0.name, bundleIdentifier: $0.bundleIdentifier)
                }
                print(services.map(\.bundleIdentifier))
                print(suggestionFeatureProvider)
            }
        }
    }

    @StateObject var settings = Settings()
    @State var isSuggestionFeatureEnabledListPickerOpen = false
    @State var isSuggestionFeatureDisabledLanguageListViewOpen = false
    @State var isTabToAcceptSuggestionModifierViewOpen = false

    var body: some View {
        Form {
            Picker(selection: $settings.suggestionPresentationMode) {
                ForEach(PresentationMode.allCases, id: \.rawValue) {
                    switch $0 {
                    case .nearbyTextCursor:
                        Text("Nearby text cursor").tag($0)
                    case .floatingWidget:
                        Text("Floating widget").tag($0)
                    }
                }
            } label: {
                Text("Presentation")
            }

            Picker(selection: Binding(get: {
                switch settings.suggestionFeatureProvider {
                case let .builtIn(provider):
                    return SuggestionFeatureProviderOption(
                        name: "",
                        builtInProvider: provider
                    )
                case let .extension(name, identifier):
                    return SuggestionFeatureProviderOption(
                        name: name,
                        bundleIdentifier: identifier
                    )
                }
            }, set: { (option: SuggestionFeatureProviderOption) in
                if let provider = option.builtInProvider {
                    settings.suggestionFeatureProvider = .builtIn(provider)
                } else {
                    settings.suggestionFeatureProvider = .extension(
                        name: option.name,
                        bundleIdentifier: option.bundleIdentifier ?? ""
                    )
                }
            })) {
                ForEach(BuiltInSuggestionFeatureProvider.allCases, id: \.rawValue) {
                    switch $0 {
                    case .gitHubCopilot:
                        Text("GitHub Copilot")
                            .tag(SuggestionFeatureProviderOption(name: "", builtInProvider: $0))
                    case .codeium:
                        Text("Codeium")
                            .tag(SuggestionFeatureProviderOption(name: "", builtInProvider: $0))
                    }
                }

                ForEach(settings.extensionSuggestionFeatureProviderOptions, id: \.self) { item in
                    Text(item.name).tag(item)
                }

                if case let .extension(name, identifier) = settings.suggestionFeatureProvider {
                    if !settings.extensionSuggestionFeatureProviderOptions.contains(where: {
                        $0.bundleIdentifier == identifier
                    }) {
                        Text("\(name) (Not found)").tag(
                            SuggestionFeatureProviderOption(
                                name: name,
                                bundleIdentifier: identifier
                            )
                        )
                    }
                }
            } label: {
                Text("Feature provider")
            }

            Toggle(isOn: $settings.realtimeSuggestionToggle) {
                Text("Real-time suggestion")
            }

            Toggle(isOn: $settings.acceptSuggestionWithTab) {
                HStack {
                    Text("Accept suggestion with Tab")

                    Button(action: {
                        isTabToAcceptSuggestionModifierViewOpen = true
                    }) {
                        Image(systemName: "gearshape.fill")
                    }
                    .buttonStyle(.plain)
                }
            }.sheet(isPresented: $isTabToAcceptSuggestionModifierViewOpen) {
                TabToAcceptSuggestionModifierView()
            }

            Toggle(isOn: $settings.dismissSuggestionWithEsc) {
                Text("Dismiss suggestion with ESC")
            }

            HStack {
                Toggle(isOn: $settings.disableSuggestionFeatureGlobally) {
                    Text("Disable suggestion feature globally")
                }

                Button("Exception list") {
                    isSuggestionFeatureEnabledListPickerOpen = true
                }
            }.sheet(isPresented: $isSuggestionFeatureEnabledListPickerOpen) {
                SuggestionFeatureEnabledProjectListView(
                    isOpen: $isSuggestionFeatureEnabledListPickerOpen
                )
            }

            HStack {
                Button("Disabled language list") {
                    isSuggestionFeatureDisabledLanguageListViewOpen = true
                }
            }.sheet(isPresented: $isSuggestionFeatureDisabledLanguageListViewOpen) {
                SuggestionFeatureDisabledLanguageListView(
                    isOpen: $isSuggestionFeatureDisabledLanguageListViewOpen
                )
            }

            HStack {
                Slider(value: $settings.realtimeSuggestionDebounce, in: 0.1...2, step: 0.1) {
                    Text("Real-time suggestion debounce")
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
                Text("Hide buttons")
            }

            Toggle(isOn: $settings.hideCommonPrecedingSpacesInSuggestion) {
                Text("Hide common preceding spaces")
            }

            CodeHighlightThemePicker(scenario: .suggestion)

            FontPicker(font: $settings.font) {
                Text("Font")
            }
        }
    }

    struct TabToAcceptSuggestionModifierView: View {
        final class Settings: ObservableObject {
            @AppStorage(\.acceptSuggestionWithModifierCommand)
            var needCommand
            @AppStorage(\.acceptSuggestionWithModifierOption)
            var needOption
            @AppStorage(\.acceptSuggestionWithModifierShift)
            var needShift
            @AppStorage(\.acceptSuggestionWithModifierControl)
            var needControl
            @AppStorage(\.acceptSuggestionWithModifierOnlyForSwift)
            var onlyForSwift
        }

        @StateObject var settings = Settings()
        @Environment(\.dismiss) var dismiss

        var body: some View {
            VStack(spacing: 0) {
                Form {
                    Text("Accept suggestion with modifier")
                        .font(.headline)
                    HStack {
                        Toggle(isOn: $settings.needCommand) {
                            Text("Command")
                        }
                        Toggle(isOn: $settings.needOption) {
                            Text("Option")
                        }
                        Toggle(isOn: $settings.needShift) {
                            Text("Shift")
                        }
                        Toggle(isOn: $settings.needControl) {
                            Text("Control")
                        }
                    }
                    Toggle(isOn: $settings.onlyForSwift) {
                        Text("Only require modifiers for Swift")
                    }
                }
                .padding()

                Divider()

                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Text("Done")
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding()
            }
        }
    }
}

#Preview {
    SuggestionSettingsGeneralSectionView()
        .padding()
}

#Preview {
    SuggestionSettingsGeneralSectionView.TabToAcceptSuggestionModifierView()
}

