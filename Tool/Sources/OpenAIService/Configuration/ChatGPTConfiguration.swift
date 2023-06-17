import Foundation
import Preferences

public protocol ChatGPTConfiguration {
    var featureProvider: ChatFeatureProvider { get }
    var temperature: Double { get }
    var model: String { get }
    var endpoint: String { get }
    var apiKey: String { get }
    var stop: [String] { get }
    var maxTokens: Int { get }
    var minimumReplyTokens: Int { get }
}

public extension ChatGPTConfiguration {
    func endpoint(for provider: ChatFeatureProvider) -> String {
        switch provider {
        case .openAI:
            let baseURL = UserDefaults.shared.value(for: \.openAIBaseURL)
            if baseURL.isEmpty { return "https://api.openai.com/v1/chat/completions" }
            return "\(baseURL)/v1/chat/completions"
        case .azureOpenAI:
            let baseURL = UserDefaults.shared.value(for: \.azureOpenAIBaseURL)
            let deployment = UserDefaults.shared.value(for: \.azureChatGPTDeployment)
            let version = "2023-05-15"
            if baseURL.isEmpty { return "" }
            return "\(baseURL)/openai/deployments/\(deployment)/chat/completions?api-version=\(version)"
        }
    }

    func apiKey(for provider: ChatFeatureProvider) -> String {
        switch provider {
        case .openAI:
            return UserDefaults.shared.value(for: \.openAIAPIKey)
        case .azureOpenAI:
            return UserDefaults.shared.value(for: \.azureOpenAIAPIKey)
        }
    }

    func overriding(
        _ overrides: OverridingChatGPTConfiguration<Self>.Overriding = .init()
    ) -> OverridingChatGPTConfiguration<Self> {
        .init(overriding: self, with: overrides)
    }
}

