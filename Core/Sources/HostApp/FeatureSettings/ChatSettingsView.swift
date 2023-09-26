import Preferences
import SwiftUI

struct ChatSettingsView: View {
    class Settings: ObservableObject {
        static let availableLocalizedLocales = Locale.availableLocalizedLocales
        @AppStorage(\.chatGPTLanguage) var chatGPTLanguage
        @AppStorage(\.chatGPTTemperature) var chatGPTTemperature
        @AppStorage(\.chatGPTMaxMessageCount) var chatGPTMaxMessageCount
        @AppStorage(\.chatFontSize) var chatFontSize
        @AppStorage(\.chatCodeFontSize) var chatCodeFontSize
        @AppStorage(\.maxFocusedCodeLineCount)
        var maxFocusedCodeLineCount
        @AppStorage(\.useCodeScopeByDefaultInChatContext)
        var useCodeScopeByDefaultInChatContext
        @AppStorage(\.defaultChatFeatureChatModelId) var defaultChatFeatureChatModelId
        @AppStorage(\.defaultChatSystemPrompt) var defaultChatSystemPrompt
        @AppStorage(\.chatSearchPluginMaxIterations) var chatSearchPluginMaxIterations
        @AppStorage(\.defaultChatFeatureEmbeddingModelId) var defaultChatFeatureEmbeddingModelId
        @AppStorage(\.chatModels) var chatModels
        @AppStorage(\.embeddingModels) var embeddingModels

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
            Divider()
            pluginForm
        }
    }

    @ViewBuilder
    var chatSettingsForm: some View {
        Form {
            Picker(
                "Chat Model",
                selection: $settings.defaultChatFeatureChatModelId
            ) {
                if !settings.chatModels
                    .contains(where: { $0.id == settings.defaultChatFeatureChatModelId })
                {
                    Text(
                        (settings.chatModels.first?.name).map { "\($0) (Default)" }
                            ?? "No Model Found"
                    )
                    .tag(settings.defaultChatFeatureChatModelId)
                }

                ForEach(settings.chatModels, id: \.id) { chatModel in
                    Text(chatModel.name).tag(chatModel.id)
                }
            }

            Picker(
                "Embedding Model",
                selection: $settings.defaultChatFeatureEmbeddingModelId
            ) {
                if !settings.embeddingModels
                    .contains(where: { $0.id == settings.defaultChatFeatureEmbeddingModelId })
                {
                    Text(
                        (settings.embeddingModels.first?.name).map { "\($0) (Default)" }
                            ?? "No Model Found"
                    )
                    .tag(settings.defaultChatFeatureEmbeddingModelId)
                }

                ForEach(settings.embeddingModels, id: \.id) { embeddingModel in
                    Text(embeddingModel.name).tag(embeddingModel.id)
                }
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

            VStack(alignment: .leading, spacing: 4) {
                Text("Default System Prompt")
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
            Toggle(isOn: $settings.useCodeScopeByDefaultInChatContext) {
                Text("Use @code scope by default in chat context.")
            }

            HStack {
                TextField(text: .init(get: {
                    "\(Int(settings.maxFocusedCodeLineCount))"
                }, set: {
                    settings.maxFocusedCodeLineCount = Int($0) ?? 0
                })) {
                    Text("Max focused code line count in chat context")
                }
                .textFieldStyle(.roundedBorder)

                Text("lines")
            }
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
                Text("Search Plugin Max Iterations")
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
}

// MARK: - Preview

struct ChatSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ChatSettingsView()
    }
}

