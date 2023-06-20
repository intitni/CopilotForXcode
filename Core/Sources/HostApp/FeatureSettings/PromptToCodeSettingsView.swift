import SwiftUI

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
        init() {}
    }

    @StateObject var settings = Settings()

    var body: some View {
        VStack(alignment: .center) {
            Form {
                Toggle(isOn: $settings.promptToCodeGenerateDescription) {
                    Text("Generate Description")
                }

                Toggle(isOn: $settings.promptToCodeGenerateDescriptionInUserPreferredLanguage) {
                    Text("Generate Description in user preferred language")
                }
            }

            Divider()

            Text("Mirroring Settings of Suggestion Feature")
                .foregroundColor(.white)
                .padding(.vertical, 2)
                .padding(.horizontal, 8)
                .background(
                    Color.accentColor,
                    in: RoundedRectangle(cornerRadius: 20)
                )

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
        }
    }
}

struct PromptToCodeSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PromptToCodeSettingsView()
    }
}

