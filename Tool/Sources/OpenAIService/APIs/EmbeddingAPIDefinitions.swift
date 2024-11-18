import AIModel
import Foundation
import Preferences
import CodableWrappers

protocol EmbeddingAPI {
    func embed(text: String) async throws -> EmbeddingResponse
    func embed(texts: [String]) async throws -> EmbeddingResponse
    func embed(tokens: [[Int]]) async throws -> EmbeddingResponse
}

public struct EmbeddingResponse: Decodable {
    public struct Object: Decodable {
        public var embedding: [Float]
        public var index: Int
        @FallbackDecoding<EmptyString>
        public var object: String
    }

    @FallbackDecoding<EmptyArray>
    public var data: [Object]
    @FallbackDecoding<EmptyString>
    public var model: String

    public struct Usage: Decodable {
        @FallbackDecoding<EmptyInt>
        public var prompt_tokens: Int
        @FallbackDecoding<EmptyInt>
        public var total_tokens: Int
        
        public struct Fallback: FallbackValueProvider {
            public static var defaultValue: Usage { Usage(prompt_tokens: 0, total_tokens: 0) }
        }
    }

    @FallbackDecoding<Usage.Fallback>
    public var usage: Usage
}


