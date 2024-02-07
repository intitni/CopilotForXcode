import Preferences
import SharedUIComponents
import SwiftUI

#if canImport(ProHostApp)
import ProHostApp
#endif

struct PromptToCodeSettingsView: View {
    final class Settings: ObservableObject {
        @AppStorage(\.hideCommonPrecedingSpacesInSuggestion)
        var hideCommonPrecedingSpacesInSuggestion
        @AppStorage(\.suggestionCodeFontSize)
        var suggestionCodeFontSize
        @AppStorage(\.promptToCodeGenerateDescription)
        var promptToCodeGenerateDescription
        @AppStorage(\.promptToCodeGenerateDescriptionInUserPreferredLanguage)
        var promptToCodeGenerateDescriptionInUserPreferredLanguage
        @AppStorage(\.promptToCodeChatModelId)
        var promptToCodeChatModelId
        @AppStorage(\.promptToCodeEmbeddingModelId)
        var promptToCodeEmbeddingModelId

        @AppStorage(\.chatModels) var chatModels
        @AppStorage(\.embeddingModels) var embeddingModels
        init() {}
    }

    @StateObject var settings = Settings()

    var body: some View {
        VStack(alignment: .center) {
            Form {
                Picker(
                    "Chat Model",
                    selection: $settings.promptToCodeChatModelId
                ) {
                    Text("Same as Chat Feature").tag("")

                    if !settings.chatModels
                        .contains(where: { $0.id == settings.promptToCodeChatModelId }),
                        !settings.promptToCodeChatModelId.isEmpty
                    {
                        Text(
                            (settings.chatModels.first?.name).map { "\($0) (Default)" }
                                ?? "No Model Found"
                        )
                        .tag(settings.promptToCodeChatModelId)
                    }

                    ForEach(settings.chatModels, id: \.id) { chatModel in
                        Text(chatModel.name).tag(chatModel.id)
                    }
                }

                Picker(
                    "Embedding Model",
                    selection: $settings.promptToCodeEmbeddingModelId
                ) {
                    Text("Same as Chat Feature").tag("")

                    if !settings.embeddingModels
                        .contains(where: { $0.id == settings.promptToCodeEmbeddingModelId }),
                        !settings.promptToCodeEmbeddingModelId.isEmpty
                    {
                        Text(
                            (settings.embeddingModels.first?.name).map { "\($0) (Default)" }
                                ?? "No Model Found"
                        )
                        .tag(settings.promptToCodeEmbeddingModelId)
                    }

                    ForEach(settings.embeddingModels, id: \.id) { embeddingModel in
                        Text(embeddingModel.name).tag(embeddingModel.id)
                    }
                }

                Toggle(isOn: $settings.promptToCodeGenerateDescription) {
                    Text("Generate Description")
                }

                Toggle(isOn: $settings.promptToCodeGenerateDescriptionInUserPreferredLanguage) {
                    Text("Generate Description in user preferred language")
                }
            }

            SettingsDivider("Mirroring Settings of Suggestion Feature")

            Form {
                Toggle(isOn: $settings.hideCommonPrecedingSpacesInSuggestion) {
                    Text("Hide Common Preceding Spaces")
                }.disabled(true)

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
                }.disabled(true)
            }

            ScopeForm()
        }
    }

    struct ScopeForm: View {
        class Settings: ObservableObject {
            @AppStorage(\.enableSenseScopeByDefaultInPromptToCode)
            var enableSenseScopeByDefaultInPromptToCode: Bool
            init() {}
        }

        @StateObject var settings = Settings()

        var body: some View {
            SettingsDivider("Scopes")

            VStack {
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
                        Toggle(isOn: $settings.enableSenseScopeByDefaultInPromptToCode) {
                            Text("Enable by default")
                        }
                    }
                }

                #endif
            }
        }
    }
}

#Preview {
    PromptToCodeSettingsView()
        .padding()
}

