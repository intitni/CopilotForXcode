import Preferences
import SharedUIComponents
import SwiftUI

#if canImport(ProHostApp)
import ProHostApp
#endif

struct ChatSettingsGeneralSectionView: View {
    class Settings: ObservableObject {
        static let availableLocalizedLocales = Locale.availableLocalizedLocales
        @AppStorage(\.chatGPTLanguage) var chatGPTLanguage
        @AppStorage(\.chatGPTTemperature) var chatGPTTemperature
        @AppStorage(\.chatGPTMaxMessageCount) var chatGPTMaxMessageCount
        @AppStorage(\.chatFontSize) var chatFontSize
        @AppStorage(\.chatCodeFont) var chatCodeFont

        @AppStorage(\.defaultChatFeatureChatModelId) var defaultChatFeatureChatModelId
        @AppStorage(\.preferredChatModelIdForUtilities) var utilityChatModelId
        @AppStorage(\.defaultChatSystemPrompt) var defaultChatSystemPrompt
        @AppStorage(\.chatSearchPluginMaxIterations) var chatSearchPluginMaxIterations
        @AppStorage(\.defaultChatFeatureEmbeddingModelId) var defaultChatFeatureEmbeddingModelId
        @AppStorage(\.chatModels) var chatModels
        @AppStorage(\.embeddingModels) var embeddingModels
        @AppStorage(\.wrapCodeInChatCodeBlock) var wrapCodeInCodeBlock
        @AppStorage(
            \.keepFloatOnTopIfChatPanelAndXcodeOverlaps
        ) var keepFloatOnTopIfChatPanelAndXcodeOverlaps
        @AppStorage(
            \.disableFloatOnTopWhenTheChatPanelIsDetached
        ) var disableFloatOnTopWhenTheChatPanelIsDetached
        @AppStorage(\.openChatMode) var openChatMode
        @AppStorage(\.openChatInBrowserURL) var openChatInBrowserURL
        @AppStorage(\.openChatInBrowserInInAppBrowser) var openChatInBrowserInInAppBrowser

        init() {}
    }

    @Environment(\.openURL) var openURL
    @Environment(\.toast) var toast
    @StateObject var settings = Settings()
    @State var maxTokenOverLimit = false

    var body: some View {
        VStack {
            openChatSettingsForm
            SettingsDivider("Conversation")
            chatSettingsForm
            SettingsDivider("UI")
            uiForm
            SettingsDivider("Plugin")
            pluginForm
        }
    }

    @ViewBuilder
    var openChatSettingsForm: some View {
        Form {
            Picker(
                "Open Chat Mode",
                selection: $settings.openChatMode
            ) {
                ForEach(OpenChatMode.allCases, id: \.rawValue) { mode in
                    switch mode {
                    case .chatPanel:
                        Text("Open chat panel").tag(mode)
                    case .browser:
                        Text("Open web page in browser").tag(mode)
                    case .codeiumChat:
                        Text("Open Codeium chat tab").tag(mode)
                    }
                }
            }

            if settings.openChatMode == .browser {
                TextField(
                    "Chat web page URL",
                    text: $settings.openChatInBrowserURL,
                    prompt: Text("https://")
                )
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)
                .autocorrectionDisabled(true)

                #if canImport(ProHostApp)
                WithFeatureEnabled(\.browserTab) {
                    Toggle(
                        "Open web page in chat panel",
                        isOn: $settings.openChatInBrowserInInAppBrowser
                    )
                }
                #endif
            }
        }
    }

    @ViewBuilder
    var chatSettingsForm: some View {
        Form {
            Picker(
                "Chat model",
                selection: $settings.defaultChatFeatureChatModelId
            ) {
                let allModels = settings.chatModels + [.init(
                    id: "com.github.copilot",
                    name: "GitHub Copilot (poc)",
                    format: .openAI,
                    info: .init()
                )]

                if !allModels.contains(where: { $0.id == settings.defaultChatFeatureChatModelId }) {
                    Text(
                        (allModels.first?.name).map { "\($0) (Default)" } ?? "No model found"
                    )
                    .tag(settings.defaultChatFeatureChatModelId)
                }

                ForEach(allModels, id: \.id) { chatModel in
                    Text(chatModel.name).tag(chatModel.id)
                }
            }

            Picker(
                "Utility chat model",
                selection: $settings.utilityChatModelId
            ) {
                Text("Use the default model").tag("")

                if !settings.chatModels.contains(where: { $0.id == settings.utilityChatModelId }),
                   !settings.utilityChatModelId.isEmpty
                {
                    Text(
                        (settings.chatModels.first?.name).map { "\($0) (Default)" }
                            ?? "No Model Found"
                    )
                    .tag(settings.utilityChatModelId)
                }

                ForEach(settings.chatModels, id: \.id) { chatModel in
                    Text(chatModel.name).tag(chatModel.id)
                }
            }

            Picker(
                "Embedding model",
                selection: $settings.defaultChatFeatureEmbeddingModelId
            ) {
                if !settings.embeddingModels
                    .contains(where: { $0.id == settings.defaultChatFeatureEmbeddingModelId })
                {
                    Text(
                        (settings.embeddingModels.first?.name).map { "\($0) (Default)" }
                            ?? "No model found"
                    )
                    .tag(settings.defaultChatFeatureEmbeddingModelId)
                }

                ForEach(settings.embeddingModels, id: \.id) { embeddingModel in
                    Text(embeddingModel.name).tag(embeddingModel.id)
                }
            }

            if #available(macOS 13.0, *) {
                LabeledContent("Reply in language") {
                    languagePicker
                }
            } else {
                HStack {
                    Text("Reply in language")
                    languagePicker
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
                .foregroundColor(settings.chatGPTTemperature >= 1 ? .red : .secondary)
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

            VStack(alignment: .leading, spacing: 4) {
                Text("Default system prompt")
                EditableText(text: $settings.defaultChatSystemPrompt)
                    .lineLimit(6)
            }
            .padding(.vertical, 4)
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

            FontPicker(font: $settings.chatCodeFont) {
                Text("Font of code")
            }

            Toggle(isOn: $settings.wrapCodeInCodeBlock) {
                Text("Wrap text in code block")
            }

            CodeHighlightThemePicker(scenario: .chat)

            Toggle(isOn: $settings.disableFloatOnTopWhenTheChatPanelIsDetached) {
                Text("Disable always-on-top when the chat panel is detached")
            }

            Toggle(isOn: $settings.keepFloatOnTopIfChatPanelAndXcodeOverlaps) {
                Text("Keep always-on-top if the chat panel and Xcode overlaps and Xcode is active")
            }.disabled(!settings.disableFloatOnTopWhenTheChatPanelIsDetached)
        }
    }

    @ViewBuilder
    var pluginForm: some View {
        Form {
            TextField(text: .init(get: {
                "\(Int(settings.chatSearchPluginMaxIterations))"
            }, set: {
                settings.chatSearchPluginMaxIterations = Int($0) ?? 0
            })) {
                Text("Search plugin max iterations")
            }
            .textFieldStyle(.roundedBorder)
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
                "Auto-detected by LLM",
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
                    ? "Auto-detected by LLM"
                    : settings.chatGPTLanguage
            )
        }
    }
}

// MARK: - Preview

//
// #Preview {
//    ScrollView {
//        ChatSettingsView()
//            .padding()
//    }
//    .frame(height: 800)
//    .environment(\.overrideFeatureFlag, \.never)
// }
//

