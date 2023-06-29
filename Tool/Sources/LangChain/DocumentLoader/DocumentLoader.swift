import Foundation
import JSONRPC

public struct Document: Codable {
    public var pageContent: String
    public var metadata: JSONValue
    public init(pageContent: String, metadata: JSONValue) {
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

