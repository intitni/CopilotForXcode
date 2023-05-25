import AppKit
import Client
import Preferences
import SuggestionModel
import SwiftUI

final class OpenAIViewSettings: ObservableObject {
    static let availableLocalizedLocales = Locale.availableLocalizedLocales
    @AppStorage(\.openAIAPIKey) var openAIAPIKey: String
    @AppStorage(\.chatGPTModel) var chatGPTModel: String
    @AppStorage(\.chatGPTEndpoint) var chatGPTEndpoint: String
    @AppStorage(\.chatGPTLanguage) var chatGPTLanguage: String
    @AppStorage(\.chatGPTMaxToken) var chatGPTMaxToken: Int
    @AppStorage(\.chatGPTTemperature) var chatGPTTemperature: Double
    @AppStorage(\.chatGPTMaxMessageCount) var chatGPTMaxMessageCount: Int
    init() {}
}

struct OpenAIView: View {
    let apiKeyURL = URL(string: "https://platform.openai.com/account/api-keys")!
    let modelURL = URL(
        string: "https://platform.openai.com/docs/models/model-endpoint-compatibility"
    )!
    @Environment(\.openURL) var openURL
    @StateObject var settings = OpenAIViewSettings()

    var body: some View {
        Form {
            HStack {
                SecureField(text: $settings.openAIAPIKey, prompt: Text("sk-*")) {
                    Text("OpenAI API Key")
                }
                .textFieldStyle(.roundedBorder)
                Button(action: {
                    openURL(apiKeyURL)
                }) {
                    Image(systemName: "questionmark.circle.fill")
                }.buttonStyle(.plain)
            }

            HStack {
                Picker(selection: $settings.chatGPTModel) {
                    if !settings.chatGPTModel.isEmpty,
                       ChatGPTModel(rawValue: settings.chatGPTModel) == nil
                    {
                        Text(settings.chatGPTModel).tag(settings.chatGPTModel)
                    }
                    ForEach(ChatGPTModel.allCases, id: \.self) { model in
                        Text(model.rawValue).tag(model.rawValue)
                    }
                } label: {
                    Text("ChatGPT Model")
                }.pickerStyle(.menu)
                Button(action: {
                    openURL(modelURL)
                }) {
                    Image(systemName: "questionmark.circle.fill")
                }.buttonStyle(.plain)
            }

            TextField(
                text: $settings.chatGPTEndpoint,
                prompt: Text("https://api.openai.com/v1/chat/completions")
            ) {
                Text("ChatGPT Server")
            }.textFieldStyle(.roundedBorder)

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

            if let model = ChatGPTModel(rawValue: settings.chatGPTModel) {
                let binding = Binding(
                    get: { String(settings.chatGPTMaxToken) },
                    set: {
                        if let selectionMaxToken = Int($0) {
                            settings.chatGPTMaxToken = model
                                .maxToken < selectionMaxToken ? model
                                .maxToken : selectionMaxToken
                        } else {
                            settings.chatGPTMaxToken = 0
                        }
                    }
                )
                HStack {
                    Stepper(
                        value: $settings.chatGPTMaxToken,
                        in: 0...model.maxToken,
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
            }
        }
    }

    var languagePicker: some View {
        Menu {
            if !settings.chatGPTLanguage.isEmpty,
               !OpenAIViewSettings.availableLocalizedLocales
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
                OpenAIViewSettings.availableLocalizedLocales,
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

struct OpenAIView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 8) {
            OpenAIView()
        }
        .frame(height: 800)
        .padding(.all, 8)
    }
}

