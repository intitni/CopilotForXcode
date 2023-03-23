import AppKit
import Client
import CopilotModel
import Preferences
import SwiftUI

final class OpenAIViewSettings: ObservableObject {
    @AppStorage(\.openAIAPIKey) var openAIAPIKey: String
    @AppStorage(\.chatGPTModel) var chatGPTModel: String
    @AppStorage(\.chatGPTEndpoint) var chatGPTEndpoint: String
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
                        Text("OpenAI API Key")
                        TextField(text: $settings.openAIAPIKey, prompt: Text("sk-*")) {
                            EmptyView()
                        }.textFieldStyle(.copilot)
                        Button(action: {
                            openURL(apiKeyURL)
                        }) {
                            Image(systemName: "questionmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }

                    HStack {
                        Text("ChatGPT Model")
                        TextField(text: $settings.chatGPTModel, prompt: Text("gpt-3.5-turbo")) {
                            EmptyView()
                        }.textFieldStyle(.copilot)

                        Button(action: {
                            openURL(modelURL)
                        }) {
                            Image(systemName: "questionmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }

                    HStack {
                        Text("ChatGPT Endpoint")
                        TextField(
                            text: $settings.chatGPTEndpoint,
                            prompt: Text("https://api.openai.com/v1/chat/completions")
                        ) {
                            EmptyView()
                        }.textFieldStyle(.copilot)
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
