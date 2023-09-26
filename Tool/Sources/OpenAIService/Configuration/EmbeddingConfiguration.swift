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

