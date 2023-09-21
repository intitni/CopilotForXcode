import AIModel
import Foundation
import Preferences

public struct UserPreferenceEmbeddingConfiguration: EmbeddingConfiguration {
    public var model: EmbeddingModel {
        let models = UserDefaults.shared.value(for: \.embeddingModels)
        let id = UserDefaults.shared.value(for: \.defaultChatFeatureEmbeddingModelId)
        return models.first { $0.id == id }
            ?? models.first ?? .init(id: "", name: "", format: .openAI, info: .init())
    }

    public var maxToken: Int {
        model.info.maxTokens
    }

    #warning("TODO: Support different dimensions.")
    public var dimensions: Int {
        1536 // text-embedding-ada-002
    }

    public init() {}
}

public class OverridingEmbeddingConfiguration<
    Configuration: EmbeddingConfiguration
>: EmbeddingConfiguration {
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

    private let configuration: Configuration
    public var overriding = Overriding()

    public init(overriding configuration: Configuration, with overrides: Overriding = .init()) {
        overriding = overrides
        self.configuration = configuration
    }

    public var model: EmbeddingModel {
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

