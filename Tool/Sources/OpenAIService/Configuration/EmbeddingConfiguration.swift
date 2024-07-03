import AIModel
import Foundation
import Keychain
import Preferences

public protocol EmbeddingConfiguration {
    var model: EmbeddingModel? { get }
    var apiKey: String { get }
    var maxToken: Int { get }
    var dimensions: Int { get }
}

public extension EmbeddingConfiguration {
    var endpoint: String {
        model?.endpoint ?? ""
    }
    
    var apiKey: String {
        guard let name = model?.info.apiKeyName else { return "" }
        return (try? Keychain.apiKey.get(name)) ?? ""
    }

    func overriding(
        _ overrides: OverridingEmbeddingConfiguration.Overriding
    ) -> OverridingEmbeddingConfiguration {
        .init(overriding: self, with: overrides)
    }

    func overriding(
        _ update: (inout OverridingEmbeddingConfiguration.Overriding) -> Void = { _ in }
    ) -> OverridingEmbeddingConfiguration {
        var overrides = OverridingEmbeddingConfiguration.Overriding()
        update(&overrides)
        return .init(overriding: self, with: overrides)
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

