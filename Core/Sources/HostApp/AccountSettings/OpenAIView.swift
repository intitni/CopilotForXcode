import AppKit
import Client
import OpenAIService
import Preferences
import SuggestionModel
import SwiftUI

struct OpenAIView: View {
    final class Settings: ObservableObject {
        @AppStorage(\.openAIAPIKey) var openAIAPIKey: String
        @AppStorage(\.chatGPTModel) var chatGPTModel: String
        @AppStorage(\.embeddingModel) var embeddingModel: String
        @AppStorage(\.openAIBaseURL) var openAIBaseURL: String
        init() {}
    }

    let apiKeyURL = URL(string: "https://platform.openai.com/account/api-keys")!
    let modelURL = URL(
        string: "https://platform.openai.com/docs/models/model-endpoint-compatibility"
    )!
    @Environment(\.openURL) var openURL
    @Environment(\.toast) var toast
    @State var isTesting = false
    @StateObject var settings = Settings()

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
                TextField(
                    text: $settings.openAIBaseURL,
                    prompt: Text("https://api.openai.com")
                ) {
                    Text("OpenAI Base URL")
                }.textFieldStyle(.roundedBorder)

                Button("Test") {
                    Task { @MainActor in
                        isTesting = true
                        defer { isTesting = false }
                        do {
                            let reply =
                                try await ChatGPTService(
                                    configuration: UserPreferenceChatGPTConfiguration()
                                )
                                .sendAndWait(content: "Hello", summary: nil)
                            toast("ChatGPT replied: \(reply ?? "N/A")", .info)
                        } catch {
                            toast(error.localizedDescription, .error)
                        }
                    }
                }.disabled(isTesting)
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
            
            HStack {
                Picker(selection: $settings.embeddingModel) {
                    if !settings.embeddingModel.isEmpty,
                       OpenAIEmbeddingModel(rawValue: settings.embeddingModel) == nil
                    {
                        Text(settings.embeddingModel).tag(settings.embeddingModel)
                    }
                    ForEach(OpenAIEmbeddingModel.allCases, id: \.self) { model in
                        Text(model.rawValue).tag(model.rawValue)
                    }
                } label: {
                    Text("Embedding Model")
                }.pickerStyle(.menu)
                Button(action: {
                    openURL(modelURL)
                }) {
                    Image(systemName: "questionmark.circle.fill")
                }.buttonStyle(.plain)
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
    }
}

