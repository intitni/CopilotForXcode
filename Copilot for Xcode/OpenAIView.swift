import AppKit
import Client
import CopilotModel
import Preferences
import SwiftUI

final class OpenAIViewSettings: ObservableObject {
    @AppStorage(\.openAIAPIKey) var openAIAPIKey: String
    @AppStorage(\.chatGPTModel) var chatGPTModel: String
    @AppStorage(\.chatGPTEndpoint) var chatGPTEndpoint: String
    @AppStorage(\.chatGPTLanguage) var chatGPTLanguage: String
    @AppStorage(\.chatGPTMaxToken) var chatGPTMaxToken: Int
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
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("OpenAI")
                    .font(.title)
                    .padding(.bottom, 12)

                Form {
                    HStack {
                        TextField(text: $settings.openAIAPIKey, prompt: Text("sk-*")) {
                            Text("OpenAI API Key")
                        }.textFieldStyle(.roundedBorder)
                        Button(action: {
                            openURL(apiKeyURL)
                        }) {
                            Image(systemName: "questionmark.circle.fill")
                        }.buttonStyle(.plain)
                    }

                    HStack {
                        Picker(selection: $settings.chatGPTModel) {
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
                    .onChange(of: settings.chatGPTModel) { newValue in
                        if let model = ChatGPTModel(rawValue: newValue) {
                            settings.chatGPTEndpoint = model.endpoint
                        }
                    }

                    Picker(selection: $settings.chatGPTLanguage) {
                        ForEach(ChatGPTLanguage.allCases, id: \.self) { language in
                            Text(language.fullName).tag(language.rawValue)
                        }
                    } label: {
                        Text("Reply in Language")
                    }.pickerStyle(.menu)

                    HStack {
                        if let model = ChatGPTModel(rawValue: settings.chatGPTModel) {
                            Stepper(
                                value: $settings.chatGPTMaxToken,
                                in: 0...model.maxToken,
                                step: 1
                            ) {
                                Text("Max Token")
                            }
                        }
                        Text(settings.chatGPTMaxToken.description)
                            .font(.body)
                            .monospacedDigit()
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.white.opacity(0.2))
                            )
                    }
                }
            }
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
        .background(Color.black)
    }
}
