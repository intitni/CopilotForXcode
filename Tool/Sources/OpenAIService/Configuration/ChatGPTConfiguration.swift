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
    var runFunctionsAutomatically: Bool { get }
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
            let version = "2023-07-01-preview"
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
        _ overrides: OverridingChatGPTConfiguration.Overriding
    ) -> OverridingChatGPTConfiguration {
        .init(overriding: self, with: overrides)
    }

    func overriding(
        _ update: (inout OverridingChatGPTConfiguration.Overriding) -> Void = { _ in }
    ) -> OverridingChatGPTConfiguration {
        var overrides = OverridingChatGPTConfiguration.Overriding()
        update(&overrides)
        return .init(overriding: self, with: overrides)
    }
}

