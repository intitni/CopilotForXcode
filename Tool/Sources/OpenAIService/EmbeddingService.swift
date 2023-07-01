import Foundation

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

struct EmbeddingRequestBody: Encodable {
    var input: [String]
    var model: String
}

struct EmbeddingFromTokensRequestBody: Encodable {
    var input: [[Int]]
    var model: String
}

public struct EmbeddingService {
    public let configuration: EmbeddingConfiguration

    public init(configuration: EmbeddingConfiguration) {
        self.configuration = configuration
    }

    public func embed(text: String) async throws -> EmbeddingResponse {
        return try await embed(text: [text])
    }

    public func embed(text: [String]) async throws -> EmbeddingResponse {
        guard let url = URL(string: configuration.endpoint) else {
            throw ChatGPTServiceError.endpointIncorrect
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(EmbeddingRequestBody(
            input: text,
            model: configuration.model
        ))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !configuration.apiKey.isEmpty {
            switch configuration.featureProvider {
            case .openAI:
                request.setValue(
                    "Bearer \(configuration.apiKey)",
                    forHTTPHeaderField: "Authorization"
                )
            case .azureOpenAI:
                request.setValue(configuration.apiKey, forHTTPHeaderField: "api-key")
            }
        }

        let (result, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw ChatGPTServiceError.responseInvalid
        }

        guard response.statusCode == 200 else {
            let error = try? JSONDecoder().decode(CompletionAPIError.self, from: result)
            throw error ?? ChatGPTServiceError
                .otherError(String(data: result, encoding: .utf8) ?? "Unknown Error")
        }

        return try JSONDecoder().decode(EmbeddingResponse.self, from: result)
    }
    
    public func embed(tokens: [[Int]]) async throws -> EmbeddingResponse {
        guard let url = URL(string: configuration.endpoint) else {
            throw ChatGPTServiceError.endpointIncorrect
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(EmbeddingFromTokensRequestBody(
            input: tokens,
            model: configuration.model
        ))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !configuration.apiKey.isEmpty {
            switch configuration.featureProvider {
            case .openAI:
                request.setValue(
                    "Bearer \(configuration.apiKey)",
                    forHTTPHeaderField: "Authorization"
                )
            case .azureOpenAI:
                request.setValue(configuration.apiKey, forHTTPHeaderField: "api-key")
            }
        }

        let (result, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw ChatGPTServiceError.responseInvalid
        }

        guard response.statusCode == 200 else {
            let error = try? JSONDecoder().decode(CompletionAPIError.self, from: result)
            throw error ?? ChatGPTServiceError
                .otherError(String(data: result, encoding: .utf8) ?? "Unknown Error")
        }

        return try JSONDecoder().decode(EmbeddingResponse.self, from: result)
    }
}

