import Preferences
import SwiftUI

struct ChatSettingsView: View {
    class Settings: ObservableObject {
        static let availableLocalizedLocales = Locale.availableLocalizedLocales
        @AppStorage(\.chatGPTLanguage) var chatGPTLanguage
        @AppStorage(\.chatGPTMaxToken) var chatGPTMaxToken
        @AppStorage(\.chatGPTTemperature) var chatGPTTemperature
        @AppStorage(\.chatGPTMaxMessageCount) var chatGPTMaxMessageCount
        @AppStorage(\.chatFontSize) var chatFontSize
        @AppStorage(\.chatCodeFontSize) var chatCodeFontSize
        @AppStorage(\.embedFileContentInChatContextIfNoSelection)
        var embedFileContentInChatContextIfNoSelection
        @AppStorage(\.maxEmbeddableFileInChatContextLineCount)
        var maxEmbeddableFileInChatContextLineCount
        @AppStorage(\.useSelectionScopeByDefaultInChatContext)
        var useSelectionScopeByDefaultInChatContext

        @AppStorage(\.chatFeatureProvider) var chatFeatureProvider
        @AppStorage(\.chatGPTModel) var chatGPTModel

        init() {}
    }

    @Environment(\.openURL) var openURL
    @Environment(\.toast) var toast
    @StateObject var settings = Settings()
    @State var maxTokenOverLimit = false

    var body: some View {
        VStack {
            chatSettingsForm
            Divider()
            uiForm
            Divider()
            contextForm
        }
    }

    @ViewBuilder
    var chatSettingsForm: some View {
        Form {
            Picker(
                "Feature Provider",
                selection: $settings.chatFeatureProvider
            ) {
                Text("OpenAI").tag(ChatFeatureProvider.openAI)
                Text("Azure OpenAI").tag(ChatFeatureProvider.azureOpenAI)
            }

            if #available(macOS 13.0, *) {
                LabeledContent("Reply in Language") {
                    languagePicker
                }
            } else {
                HStack {
                    Text("Reply in Language")
                    languagePicker
                }
            }

            let binding = Binding(
                get: { String(settings.chatGPTMaxToken) },
                set: {
                    if let selectionMaxToken = Int($0) {
                        settings.chatGPTMaxToken = selectionMaxToken
                    } else {
                        settings.chatGPTMaxToken = 0
                    }
                }
            )
            HStack {
                Stepper(
                    value: $settings.chatGPTMaxToken,
                    in: 0...Int.max,
                    step: 1
                ) {
                    Text("Max Token (Including Reply)")
                        .multilineTextAlignment(.trailing)
                }
                TextField(text: binding) {
                    EmptyView()
                }
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .foregroundColor(maxTokenOverLimit ? .red : .primary)

                if let model = ChatGPTModel(rawValue: settings.chatGPTModel),
                   settings.chatFeatureProvider == .openAI
                {
                    Text("Max: \(model.maxToken)")
                }
            }

            HStack {
                Slider(value: $settings.chatGPTTemperature, in: 0...2, step: 0.1) {
                    Text("Temperature")
                }

                Text(
                    "\(settings.chatGPTTemperature.formatted(.number.precision(.fractionLength(1))))"
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

            Picker(
                "Memory",
                selection: $settings.chatGPTMaxMessageCount
            ) {
                Text("No Limit").tag(0)
                Text("3 Messages").tag(3)
                Text("5 Messages").tag(5)
                Text("7 Messages").tag(7)
                Text("9 Messages").tag(9)
                Text("11 Messages").tag(11)
            }
        }.onAppear {
            checkMaxToken()
        }.onChange(of: settings.chatFeatureProvider) { _ in
            checkMaxToken()
        }.onChange(of: settings.chatGPTModel) { _ in
            checkMaxToken()
        }.onChange(of: settings.chatGPTMaxToken) { _ in
            checkMaxToken()
        }
    }

    @ViewBuilder
    var uiForm: some View {
        Form {
            HStack {
                TextField(text: .init(get: {
                    "\(Int(settings.chatFontSize))"
                }, set: {
                    settings.chatFontSize = Double(Int($0) ?? 0)
                })) {
                    Text("Font size of message")
                }
                .textFieldStyle(.roundedBorder)

                Text("pt")
            }

            HStack {
                TextField(text: .init(get: {
                    "\(Int(settings.chatCodeFontSize))"
                }, set: {
                    settings.chatCodeFontSize = Double(Int($0) ?? 0)
                })) {
                    Text("Font size of code block")
                }
                .textFieldStyle(.roundedBorder)

                Text("pt")
            }
        }
    }

    @ViewBuilder
    var contextForm: some View {
        Form {
            Toggle(isOn: $settings.useSelectionScopeByDefaultInChatContext) {
                Text("Use selection scope by default in chat context.")
            }
            
            Toggle(isOn: $settings.embedFileContentInChatContextIfNoSelection) {
                Text("Embed file content in chat context if no code is selected.")
            }

            HStack {
                TextField(text: .init(get: {
                    "\(Int(settings.maxEmbeddableFileInChatContextLineCount))"
                }, set: {
                    settings.maxEmbeddableFileInChatContextLineCount = Int($0) ?? 0
                })) {
                    Text("Max embeddable file")
                }
                .textFieldStyle(.roundedBorder)

                Text("lines")
            }
        }
    }

    var languagePicker: some View {
        Menu {
            if !settings.chatGPTLanguage.isEmpty,
               !Settings.availableLocalizedLocales
               .contains(settings.chatGPTLanguage)
            {
                Button(
                    settings.chatGPTLanguage,
                    action: { self.settings.chatGPTLanguage = settings.chatGPTLanguage }
                )
            }
            Button(
                "Auto-detected by ChatGPT",
                action: { self.settings.chatGPTLanguage = "" }
            )
            ForEach(
                Settings.availableLocalizedLocales,
                id: \.self
            ) { localizedLocales in
                Button(
                    localizedLocales,
                    action: { self.settings.chatGPTLanguage = localizedLocales }
                )
            }
        } label: {
            Text(
                settings.chatGPTLanguage.isEmpty
                    ? "Auto-detected by ChatGPT"
                    : settings.chatGPTLanguage
            )
        }
    }

    func checkMaxToken() {
        switch settings.chatFeatureProvider {
        case .openAI:
            if let model = ChatGPTModel(rawValue: settings.chatGPTModel) {
                maxTokenOverLimit = model.maxToken < settings.chatGPTMaxToken
            } else {
                maxTokenOverLimit = false
            }
        case .azureOpenAI:
            maxTokenOverLimit = false
        }
    }
}

// MARK: - Preview

struct ChatSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ChatSettingsView()
    }
}

