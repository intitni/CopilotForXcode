import Foundation

public protocol Embeddings {
    /// Embed search docs.
    func embedDocuments(texts: [String]) -> [[Float]]
    /// Embed query text.
    func embedQuery(text: String) -> [Float]
}
