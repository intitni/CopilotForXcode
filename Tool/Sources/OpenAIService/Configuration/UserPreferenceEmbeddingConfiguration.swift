import AIModel
import ChatBasic
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

