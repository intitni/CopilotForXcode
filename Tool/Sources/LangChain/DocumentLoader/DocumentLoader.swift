import Foundation
import JSONRPC

public struct Document: Codable {
    public typealias Metadata = [String: JSONValue]
    public var pageContent: String
    public var metadata: Metadata
    public init(pageContent: String, metadata: Metadata) {
        self.pageContent = pageContent
        self.metadata = metadata
    }
}

public protocol DocumentLoader {
    func load() async throws -> [Document]
}

extension DocumentLoader {
    func loadAndSplit(
        with textSplitter: TextSplitter = RecursiveCharacterTextSplitter()
    ) async throws -> [Document] {
        let docs = try await load()
        return try await textSplitter.splitDocuments(docs)
    }
}

