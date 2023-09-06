import AIModel
import Foundation
import Keychain
import Preferences

public protocol EmbeddingConfiguration {
    var model: EmbeddingModel { get }
    var apiKey: String { get }
    var maxToken: Int { get }
}

public extension EmbeddingConfiguration {
    var endpoint: String {
        model.endpoint
    }
    
    var apiKey: String {
        (try? Keychain.apiKey.get(model.info.apiKeyName)) ?? ""
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

