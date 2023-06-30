import Foundation
import Preferences

public typealias EmbeddingFeatureProvider = ChatFeatureProvider

public protocol EmbeddingConfiguration {
    var featureProvider: EmbeddingFeatureProvider { get }
    var endpoint: String { get }
    var apiKey: String { get }
    var maxToken: Int { get }
    var model: String { get }
}

extension EmbeddingConfiguration {
    func endpoint(for provider: EmbeddingFeatureProvider) -> String {
        switch provider {
        case .openAI:
            let baseURL = UserDefaults.shared.value(for: \.openAIBaseURL)
            if baseURL.isEmpty { return "https://api.openai.com/v1/embeddings" }
            return "\(baseURL)/v1/embeddings"
        case .azureOpenAI:
            let baseURL = UserDefaults.shared.value(for: \.azureOpenAIBaseURL)
            let deployment = UserDefaults.shared.value(for: \.azureChatGPTDeployment)
            let version = "2023-05-15"
            if baseURL.isEmpty { return "" }
            return "\(baseURL)/openai/deployments/\(deployment)/embeddings?api-version=\(version)"
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
        _ overrides: OverridingEmbeddingConfiguration<Self>.Overriding = .init()
    ) -> OverridingEmbeddingConfiguration<Self> {
        .init(overriding: self, with: overrides)
    }
}

