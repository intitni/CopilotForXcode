import AIModel
import Foundation
import Preferences

typealias CompletionAPIBuilder = (String, ChatModel, URL, CompletionRequestBody, ChatGPTPrompt)
    -> CompletionAPI

protocol CompletionAPI {
    func callAsFunction() async throws -> CompletionResponseBody
}

/// https://platform.openai.com/docs/api-reference/chat/create
struct CompletionResponseBody: Codable, Equatable {
    struct Message: Codable, Equatable {
        /// The role of the message.
        var role: ChatMessage.Role
        /// The content of the message.
        var content: String?
        /// When we want to reply to a function call with the result, we have to provide the
        /// name of the function call, and include the result in `content`.
        ///
        /// - important: It's required when the role is `function`.
        var name: String?
        /// When the bot wants to call a function, it will reply with a function call in format:
        /// ```json
        /// {
        ///   "name": "weather",
        ///   "arguments": "{ \"location\": \"earth\" }"
        /// }
        /// ```
        var function_call: CompletionRequestBody.MessageFunctionCall?
    }

    struct Choice: Codable, Equatable {
        var message: Message
        var index: Int
        var finish_reason: String
    }

    struct Usage: Codable, Equatable {
        var prompt_tokens: Int
        var completion_tokens: Int
        var total_tokens: Int
    }

    var id: String?
    var object: String
    var model: String
    var usage: Usage
    var choices: [Choice]
}

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

struct OpenAICompletionAPI: CompletionAPI {
    var apiKey: String
    var endpoint: URL
    var requestBody: CompletionRequestBody
    var model: ChatModel

    init(
        apiKey: String,
        model: ChatModel,
        endpoint: URL,
        requestBody: CompletionRequestBody
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.requestBody = requestBody
        self.requestBody.stream = false
        self.model = model
    }

    func callAsFunction() async throws -> CompletionResponseBody {
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
                assert(false, "Unsupported")
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
            return try JSONDecoder().decode(CompletionResponseBody.self, from: result)
        } catch {
            dump(error)
            throw error
        }
    }
}

