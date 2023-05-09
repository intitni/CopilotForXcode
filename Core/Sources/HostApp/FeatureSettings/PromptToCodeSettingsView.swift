import SwiftUI

struct PromptToCodeSettingsView: View {
    final class Settings: ObservableObject {
        @AppStorage(\.hideCommonPrecedingSpacesInSuggestion)
        var hideCommonPrecedingSpacesInSuggestion
        @AppStorage(\.suggestionCodeFontSize)
        var suggestionCodeFontSize
        @AppStorage(\.acceptSuggestionWithAccessibilityAPI)
        var acceptSuggestionWithAccessibilityAPI
        init() {}
    }

    @StateObject var settings = Settings()

    var body: some View {
        VStack(alignment: .center) {
            Text("Mirroring Settings of Suggestion Feature")
                .foregroundColor(.white)
                .padding(.vertical, 2)
                .padding(.horizontal, 8)
                .background(
                    Color.accentColor,
                    in: RoundedRectangle(cornerRadius: 20)
                )
                .shadow(radius: 5)

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
                
                Divider()

                Toggle(isOn: $settings.acceptSuggestionWithAccessibilityAPI) {
                    Text("Use accessibility API to accept suggestion in widget")
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

