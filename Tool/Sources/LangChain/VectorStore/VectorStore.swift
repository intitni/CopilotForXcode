import Foundation

public protocol VectorStore {
    func add(_ documents: [EmbeddedDocument]) async throws
    func set(_ documents: [EmbeddedDocument]) async throws
    func clear() async throws
    func searchWithDistance(embeddings: [Float], count: Int) async throws
        -> [(document: Document, distance: Float)]
}

public extension VectorStore {
    func search(embeddings: [Float], count: Int) async throws -> [Document] {
        try await searchWithDistance(embeddings: embeddings, count: count).map { $0.document }
    }

    func add(_ document: EmbeddedDocument) async throws {
        try await add([document])
    }
}

