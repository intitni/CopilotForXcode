import Foundation

public protocol Embeddings {
    /// Embed search docs.
    func embed(documents: [String]) async throws -> [[Float]]
    /// Embed query text.
    func embed(query: String) async throws -> [Float]
}
