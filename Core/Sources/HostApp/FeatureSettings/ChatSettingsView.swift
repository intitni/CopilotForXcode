import Preferences
import SharedUIComponents
import SwiftUI

#if canImport(ProHostApp)
import ProHostApp
#endif

struct ChatSettingsView: View {
    class Settings: ObservableObject {
        static let availableLocalizedLocales = Locale.availableLocalizedLocales
        @AppStorage(\.chatGPTLanguage) var chatGPTLanguage
        @AppStorage(\.chatGPTTemperature) var chatGPTTemperature
        @AppStorage(\.chatGPTMaxMessageCount) var chatGPTMaxMessageCount
        @AppStorage(\.chatFontSize) var chatFontSize
        @AppStorage(\.chatCodeFont) var chatCodeFont

        @AppStorage(\.defaultChatFeatureChatModelId) var defaultChatFeatureChatModelId
        @AppStorage(\.defaultChatSystemPrompt) var defaultChatSystemPrompt
        @AppStorage(\.chatSearchPluginMaxIterations) var chatSearchPluginMaxIterations
        @AppStorage(\.defaultChatFeatureEmbeddingModelId) var defaultChatFeatureEmbeddingModelId
        @AppStorage(\.chatModels) var chatModels
        @AppStorage(\.embeddingModels) var embeddingModels
        @AppStorage(\.wrapCodeInChatCodeBlock) var wrapCodeInCodeBlock

        init() {}
    }

    @Environment(\.openURL) var openURL
    @Environment(\.toast) var toast
    @StateObject var settings = Settings()
    @State var maxTokenOverLimit = false

    var body: some View {
        VStack {
            chatSettingsForm
            SettingsDivider("UI")
            uiForm
            SettingsDivider("Plugin")
            pluginForm
            ScopeForm()
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

            FontPicker(font: $settings.chatCodeFont) {
                Text("Font of code")
            }

            Toggle(isOn: $settings.wrapCodeInCodeBlock) {
                Text("Wrap code in code block")
            }

            #if canImport(ProHostApp)

            CodeHighlightThemePicker(scenario: .chat)

            #endif
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

    struct ScopeForm: View {
        class Settings: ObservableObject {
            @AppStorage(\.enableFileScopeByDefaultInChatContext)
            var enableFileScopeByDefaultInChatContext: Bool
            @AppStorage(\.enableCodeScopeByDefaultInChatContext)
            var enableCodeScopeByDefaultInChatContext: Bool
            @AppStorage(\.enableSenseScopeByDefaultInChatContext)
            var enableSenseScopeByDefaultInChatContext: Bool
            @AppStorage(\.enableProjectScopeByDefaultInChatContext)
            var enableProjectScopeByDefaultInChatContext: Bool
            @AppStorage(\.enableWebScopeByDefaultInChatContext)
            var enableWebScopeByDefaultInChatContext: Bool
            @AppStorage(\.preferredChatModelIdForSenseScope)
            var preferredChatModelIdForSenseScope: String
            @AppStorage(\.preferredChatModelIdForProjectScope)
            var preferredChatModelIdForProjectScope: String
            @AppStorage(\.preferredChatModelIdForWebScope)
            var preferredChatModelIdForWebScope: String
            @AppStorage(\.chatModels) var chatModels
            @AppStorage(\.maxFocusedCodeLineCount)
            var maxFocusedCodeLineCount

            init() {}
        }

        @StateObject var settings = Settings()

        var body: some View {
            SettingsDivider("Scopes")

            VStack {
                SubSection(
                    title: Text("File Scope"),
                    description: "Enable the bot to read the metadata of the editing file."
                ) {
                    Form {
                        Toggle(isOn: $settings.enableFileScopeByDefaultInChatContext) {
                            Text("Enable by default")
                        }
                    }
                }

                SubSection(
                    title: Text("Code Scope"),
                    description: "Enable the bot to read the code and metadata of the editing file."
                ) {
                    Form {
                        Toggle(isOn: $settings.enableCodeScopeByDefaultInChatContext) {
                            Text("Enable by default")
                        }

                        HStack {
                            TextField(text: .init(get: {
                                "\(Int(settings.maxFocusedCodeLineCount))"
                            }, set: {
                                settings.maxFocusedCodeLineCount = Int($0) ?? 0
                            })) {
                                Text("Max focused code")
                            }
                            .textFieldStyle(.roundedBorder)

                            Text("lines")
                        }
                    }
                }

                #if canImport(ProHostApp)

                SubSection(
                    title: Text("Sense Scope (Experimental)"),
                    description: IfFeatureEnabled(\.senseScopeInChat) {
                        Text("""
                        Enable the bot to access the relevant code \
                        of the editing document in the project, third party packages and the SDK.
                        """)
                    } else: {
                        VStack(alignment: .leading) {
                            Text("""
                            Enable the bot to read the relevant code \
                            of the editing document in the SDK, and
                            """)

                            WithFeatureEnabled(\.senseScopeInChat, alignment: .inlineLeading) {
                                Text("the project and third party packages.")
                            }
                        }
                    }
                ) {
                    Form {
                        Toggle(isOn: $settings.enableSenseScopeByDefaultInChatContext) {
                            Text("Enable by default")
                        }

                        Picker(
                            "Preferred Chat Model",
                            selection: $settings.preferredChatModelIdForSenseScope
                        ) {
                            Text("Use the default model").tag("")

                            if !settings.chatModels
                                .contains(where: {
                                    $0.id == settings.preferredChatModelIdForSenseScope
                                }),
                                !settings.preferredChatModelIdForSenseScope.isEmpty
                            {
                                Text(
                                    (settings.chatModels.first?.name).map { "\($0) (Default)" }
                                        ?? "No Model Found"
                                )
                                .tag(settings.preferredChatModelIdForSenseScope)
                            }

                            ForEach(settings.chatModels, id: \.id) { chatModel in
                                Text(chatModel.name).tag(chatModel.id)
                            }
                        }
                    }
                }

                SubSection(
                    title: Text("Project Scope (Experimental)"),
                    description: IfFeatureEnabled(\.projectScopeInChat) {
                        Text("""
                        Enable the bot to search code and texts \
                        in the project, third party packages and the SDK.
                        """)
                    } else: {
                        VStack(alignment: .leading) {
                            Text("""
                            Enable the bot to search code and texts \
                            in the neighboring files of the editing document, and
                            """)

                            WithFeatureEnabled(\.senseScopeInChat, alignment: .inlineLeading) {
                                Text("the project, third party packages and the SDK.")
                            }
                        }
                    }
                ) {
                    Form {
                        Toggle(isOn: $settings.enableProjectScopeByDefaultInChatContext) {
                            Text("Enable by default")
                        }

                        Picker(
                            "Preferred Chat Model",
                            selection: $settings.preferredChatModelIdForProjectScope
                        ) {
                            Text("Use the default model").tag("")

                            if !settings.chatModels
                                .contains(where: {
                                    $0.id == settings.preferredChatModelIdForProjectScope
                                }),
                                !settings.preferredChatModelIdForProjectScope.isEmpty
                            {
                                Text(
                                    (settings.chatModels.first?.name).map { "\($0) (Default)" }
                                        ?? "No Model Found"
                                )
                                .tag(settings.preferredChatModelIdForProjectScope)
                            }

                            ForEach(settings.chatModels, id: \.id) { chatModel in
                                Text(chatModel.name).tag(chatModel.id)
                            }
                        }
                    }
                }

                #endif

                SubSection(
                    title: Text("Web Scope"),
                    description: "Allow the bot to search on Bing or read a web page. The current implementation requires function calling."
                ) {
                    Form {
                        Toggle(isOn: $settings.enableWebScopeByDefaultInChatContext) {
                            Text("Enable @web scope by default in chat context.")
                        }

                        Picker(
                            "Preferred Chat Model",
                            selection: $settings.preferredChatModelIdForWebScope
                        ) {
                            Text("Use the default model").tag("")

                            if !settings.chatModels
                                .contains(where: {
                                    $0.id == settings.preferredChatModelIdForWebScope
                                }),
                                !settings.preferredChatModelIdForWebScope.isEmpty
                            {
                                Text(
                                    (settings.chatModels.first?.name).map { "\($0) (Default)" }
                                        ?? "No Model Found"
                                )
                                .tag(settings.preferredChatModelIdForWebScope)
                            }

                            ForEach(settings.chatModels, id: \.id) { chatModel in
                                Text(chatModel.name).tag(chatModel.id)
                            }
                        }
                    }
                }
            }
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

