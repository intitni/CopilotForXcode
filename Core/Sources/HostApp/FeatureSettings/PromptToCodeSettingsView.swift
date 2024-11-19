import Preferences
import SharedUIComponents
import SwiftUI

struct PromptToCodeSettingsView: View {
    final class Settings: ObservableObject {
        @AppStorage(\.hideCommonPrecedingSpacesInPromptToCode)
        var hideCommonPrecedingSpaces
        @AppStorage(\.promptToCodeCodeFont)
        var font
        @AppStorage(\.promptToCodeGenerateDescription)
        var promptToCodeGenerateDescription
        @AppStorage(\.promptToCodeGenerateDescriptionInUserPreferredLanguage)
        var promptToCodeGenerateDescriptionInUserPreferredLanguage
        @AppStorage(\.promptToCodeChatModelId)
        var promptToCodeChatModelId
        @AppStorage(\.promptToCodeEmbeddingModelId)
        var promptToCodeEmbeddingModelId
        @AppStorage(\.wrapCodeInPromptToCode) var wrapCode
        @AppStorage(\.chatModels) var chatModels
        @AppStorage(\.embeddingModels) var embeddingModels
        init() {}
    }

    @StateObject var settings = Settings()

    var body: some View {
        VStack(alignment: .center) {
            Form {
                Picker(
                    "Chat model",
                    selection: $settings.promptToCodeChatModelId
                ) {
                    Text("Same as chat feature").tag("")

                    if !settings.chatModels
                        .contains(where: { $0.id == settings.promptToCodeChatModelId }),
                        !settings.promptToCodeChatModelId.isEmpty
                    {
                        Text(
                            (settings.chatModels.first?.name).map { "\($0) (Default)" }
                                ?? "No model found"
                        )
                        .tag(settings.promptToCodeChatModelId)
                    }

                    ForEach(settings.chatModels, id: \.id) { chatModel in
                        Text(chatModel.name).tag(chatModel.id)
                    }
                }
            }

            SettingsDivider("UI")

            Form {
                Toggle(isOn: $settings.hideCommonPrecedingSpaces) {
                    Text("Hide common preceding spaces")
                }

                Toggle(isOn: $settings.wrapCode) {
                    Text("Wrap code")
                }

                CodeHighlightThemePicker(scenario: .promptToCode)

                FontPicker(font: $settings.font) {
                    Text("Font")
                }
            }
        }
    }
}

#Preview {
    PromptToCodeSettingsView()
        .padding()
}

