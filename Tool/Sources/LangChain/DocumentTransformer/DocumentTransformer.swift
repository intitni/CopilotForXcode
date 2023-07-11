import Foundation

public protocol DocumentTransformer {
    func transformDocuments(_ documents: [Document]) async throws -> [Document]
}
