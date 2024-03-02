import AIModel
import Foundation
import Preferences

protocol EmbeddingAPI {
    func embed(text: String) async throws -> EmbeddingResponse
    func embed(texts: [String]) async throws -> EmbeddingResponse
    func embed(tokens: [[Int]]) async throws -> EmbeddingResponse
}

public struct EmbeddingResponse: Decodable {
    public struct Object: Decodable {
        public var embedding: [Float]
        public var index: Int
        public var object: String
    }

    public var data: [Object]
    public var model: String

    public struct Usage: Decodable {
        public var prompt_tokens: Int
        public var total_tokens: Int
    }

    public var usage: Usage
}

