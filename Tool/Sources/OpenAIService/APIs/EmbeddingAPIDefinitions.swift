import AIModel
import Foundation
import Preferences
import CodableWrappers

protocol EmbeddingAPI {
    func embed(text: String) async throws -> EmbeddingResponse
    func embed(texts: [String]) async throws -> EmbeddingResponse
    func embed(tokens: [[Int]]) async throws -> EmbeddingResponse
}

extension EmbeddingAPI {
    static func setupExtraHeaderFields(
        _ request: inout URLRequest,
        model: EmbeddingModel,
        apiKey: String
    ) async {
        let parser = HeaderValueParser()
        for field in model.info.customHeaderInfo.headers where !field.key.isEmpty {
            let value = await parser.parse(
                field.value,
                context: .init(modelName: model.info.modelName, apiKey: apiKey)
            )
            request.setValue(value, forHTTPHeaderField: field.key)
        }
    }
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


