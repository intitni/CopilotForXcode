import AIModel
import Foundation
import Preferences

struct CompletionAPIError: Error, Codable, LocalizedError {
    struct E: Codable {
        var message: String
        var type: String
        var param: String
        var code: String
    }

    var error: E

    var errorDescription: String? { error.message }
}

struct OpenAICompletionAPI: ChatCompletionsAPI {
    var apiKey: String
    var endpoint: URL
    var requestBody: ChatCompletionsRequestBody
    var model: ChatModel

    init(
        apiKey: String,
        model: ChatModel,
        endpoint: URL,
        requestBody: ChatCompletionsRequestBody
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.requestBody = requestBody
        self.requestBody.stream = false
        self.model = model
    }

    func callAsFunction() async throws -> ChatCompletionResponseBody {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            switch model.format {
            case .openAI, .openAICompatible:
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            case .azureOpenAI:
                request.setValue(apiKey, forHTTPHeaderField: "api-key")
            case .googleAI:
                assertionFailure("Unsupported")
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

        do {
            return try JSONDecoder().decode(ChatCompletionResponseBody.self, from: result)
        } catch {
            dump(error)
            throw error
        }
    }
}

