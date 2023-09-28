import AIModel
import Foundation
import Preferences

public struct UserPreferenceEmbeddingConfiguration: EmbeddingConfiguration {
    public var embeddingModelKey: KeyPath<UserDefaultPreferenceKeys, PreferenceKey<String>>?

    public var model: EmbeddingModel? {
        let models = UserDefaults.shared.value(for: \.embeddingModels)

        if let embeddingModelKey {
            let id = UserDefaults.shared.value(for: embeddingModelKey)
            if let model = models.first(where: { $0.id == id }) {
                return model
            }
        }

        let id = UserDefaults.shared.value(for: \.defaultChatFeatureEmbeddingModelId)
        return models.first { $0.id == id }
            ?? models.first
    }

    public var maxToken: Int {
        model?.info.maxTokens ?? 0
    }

    public var dimensions: Int {
        let dimensions = model?.info.dimensions ?? 0
        if dimensions <= 0 {
            return 1536
        }
        return dimensions
    }

    public init(
        embeddingModelKey: KeyPath<UserDefaultPreferenceKeys, PreferenceKey<String>>? = nil
    ) {
        self.embeddingModelKey = embeddingModelKey
    }
}

public class OverridingEmbeddingConfiguration: EmbeddingConfiguration {
    public struct Overriding {
        public var modelId: String?
        public var model: EmbeddingModel?
        public var maxTokens: Int?
        public var dimensions: Int?

        public init(
            modelId: String? = nil,
            model: EmbeddingModel? = nil,
            maxTokens: Int? = nil,
            dimensions: Int? = nil
        ) {
            self.modelId = modelId
            self.model = model
            self.maxTokens = maxTokens
            self.dimensions = dimensions
        }
    }

    private let configuration: EmbeddingConfiguration
    public var overriding = Overriding()

    public init(
        overriding configuration: any EmbeddingConfiguration,
        with overrides: Overriding = .init()
    ) {
        overriding = overrides
        self.configuration = configuration
    }

    public var model: EmbeddingModel? {
        if let model = overriding.model { return model }
        let models = UserDefaults.shared.value(for: \.embeddingModels)
        guard let id = overriding.modelId,
              let model = models.first(where: { $0.id == id })
        else { return configuration.model }
        return model
    }

    public var maxToken: Int {
        overriding.maxTokens ?? configuration.maxToken
    }

    public var dimensions: Int {
        overriding.dimensions ?? configuration.dimensions
    }
}

