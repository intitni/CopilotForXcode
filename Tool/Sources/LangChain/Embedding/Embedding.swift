import Foundation

public protocol Embeddings {
    /// Embed search docs.
    func embed(documents: [Document]) async throws -> [EmbeddedDocument]
    /// Embed query text.
    func embed(query: String) async throws -> [Float]
}

public struct EmbeddedDocument: Codable {
    var document: Document
    var embeddings: [Float]
}
