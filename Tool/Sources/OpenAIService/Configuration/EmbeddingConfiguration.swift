import Foundation
import Preferences

public protocol EmbeddingConfiguration {
    var featureProvider: EmbeddingFeatureProvider { get }
    var endpoint: String { get }
    var apiKey: String { get }
    var maxToken: Int { get }
    var model: String { get }
}

public extension EmbeddingConfiguration {
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

    func apiKey(for provider: EmbeddingFeatureProvider) -> String {
        switch provider {
        case .openAI:
            return UserDefaults.shared.value(for: \.openAIAPIKey)
        case .azureOpenAI:
            return UserDefaults.shared.value(for: \.azureOpenAIAPIKey)
        }
    }

    func overriding(
        _ overrides: OverridingEmbeddingConfiguration<Self>.Overriding
    ) -> OverridingEmbeddingConfiguration<Self> {
        .init(overriding: self, with: overrides)
    }

    func overriding(
        _ update: (inout OverridingEmbeddingConfiguration<Self>.Overriding) -> Void = { _ in }
    ) -> OverridingEmbeddingConfiguration<Self> {
        var overrides = OverridingEmbeddingConfiguration<Self>.Overriding()
        update(&overrides)
        return .init(overriding: self, with: overrides)
    }
}

