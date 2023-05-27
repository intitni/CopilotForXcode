import AppKit
import Client
import OpenAIService
import Preferences
import SuggestionModel
import SwiftUI

final class AzureViewSettings: ObservableObject {
    @AppStorage(\.azureOpenAIAPIKey) var azureOpenAIAPIKey: String
    @AppStorage(\.azureOpenAIBaseURL) var azureOpenAIBaseURL: String
    @AppStorage(\.azureChatGPTDeployment) var azureChatGPTDeployment: String
    init() {}
}

struct AzureView: View {
    @Environment(\.toast) var toast
    @State var isTesting = false
    @StateObject var settings = AzureViewSettings()

    var body: some View {
        Form {
            SecureField(text: $settings.azureOpenAIAPIKey, prompt: Text("")) {
                Text("OpenAI Service API Key")
            }
            .textFieldStyle(.roundedBorder)

            TextField(
                text: $settings.azureOpenAIBaseURL,
                prompt: Text("https://XXXXXX.openai.azure.com")
            ) {
                Text("OpenAI Service Base URL")
            }.textFieldStyle(.roundedBorder)

            HStack {
                TextField(
                    text: $settings.azureChatGPTDeployment,
                    prompt: Text("")
                ) {
                    Text("Chat Model Deployment Name")
                }.textFieldStyle(.roundedBorder)

                Button("Test") {
                    Task { @MainActor in
                        isTesting = true
                        defer { isTesting = false }
                        do {
                            let reply = try await ChatGPTService(designatedProvider: .azureOpenAI)
                                .sendAndWait(content: "Hello", summary: nil)
                            toast(Text("ChatGPT replied: \(reply ?? "N/A")"), .info)
                        } catch {
                            toast(Text(error.localizedDescription), .error)
                        }
                    }
                }
                .disabled(isTesting)
            }
        }
    }
}

struct AzureView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 8) {
            AzureView()
        }
        .frame(height: 800)
        .padding(.all, 8)
    }
}

