import Foundation
import Preferences

public struct UserPreferenceEmbeddingConfiguration: EmbeddingConfiguration {
    public var featureProvider: ChatFeatureProvider {
        UserDefaults.shared.value(for: \.chatFeatureProvider)
    }

    public var model: String {
        let value = UserDefaults.shared.value(for: \.chatGPTModel)
        if value.isEmpty { return "text-embedding-ada-002" }
        return value
    }

    public var endpoint: String {
        endpoint(for: featureProvider)
    }

    public var apiKey: String {
        apiKey(for: featureProvider)
    }

    public var maxToken: Int {
        8191
    }
    
    public init() {}
}

public class OverridingEmbeddingConfiguration<
    Configuration: EmbeddingConfiguration
>: EmbeddingConfiguration {
    public struct Overriding {
        var featureProvider: ChatFeatureProvider?
        var model: String?
        var endPoint: String?
        var apiKey: String?
        var maxTokens: Int?

        public init(
            model: String? = nil,
            featureProvider: ChatFeatureProvider? = nil,
            endPoint: String? = nil,
            apiKey: String? = nil,
            maxTokens: Int? = nil
        ) {
            self.model = model
            self.featureProvider = featureProvider
            self.endPoint = endPoint
            self.apiKey = apiKey
            self.maxTokens = maxTokens
        }
    }

    private let configuration: Configuration
    public var overriding = Overriding()

    public init(overriding configuration: Configuration, with overrides: Overriding = .init()) {
        self.overriding = overrides
        self.configuration = configuration
    }

    public var featureProvider: ChatFeatureProvider {
        overriding.featureProvider ?? configuration.featureProvider
    }
    
    public var model: String {
        overriding.model ?? configuration.model
    }

    public var endpoint: String {
        overriding.endPoint
            ?? overriding.featureProvider.map(endpoint(for:))
            ?? configuration.endpoint
    }

    public var apiKey: String {
        overriding.apiKey
            ?? overriding.featureProvider.map(apiKey(for:))
            ?? configuration.apiKey
    }
    
    public var maxToken: Int {
        overriding.maxTokens ?? configuration.maxToken
    }
}

