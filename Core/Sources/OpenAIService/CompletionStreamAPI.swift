import AsyncAlgorithms
import Foundation

typealias CompletionStreamAPIBuilder = (String, URL, CompletionRequestBody) -> CompletionStreamAPI

protocol CompletionStreamAPI {
    func callAsFunction() async throws -> (
        trunkStream: AsyncThrowingStream<CompletionStreamDataTrunk, Error>,
        cancel: Cancellable
    )
}

/// https://platform.openai.com/docs/api-reference/chat/create
struct CompletionRequestBody: Codable {
    var model: String
    var messages: [ChatMessage]
    var temperature: Double?
    var top_p: Double?
    var n: Double?
    var stream: Bool?
    var stop: [String]?
    var max_tokens: Int?
    var presence_penalty: Double?
    var frequency_penalty: Double?
    var logit_bias: [String: Double]?
    var user: String?
}

struct CompletionStreamDataTrunk: Codable {
    var id: String
    var object: String
    var created: Int
    var model: String
    var choices: [Choice]

    struct Choice: Codable {
        var delta: Delta
        var index: Int
        var finish_reason: String?

        struct Delta: Codable {
            var role: ChatMessage.Role?
            var content: String?
        }
    }
}

struct OpenAICompletionStreamAPI: CompletionStreamAPI {
    var apiKey: String
    var endpoint: URL
    var requestBody: CompletionRequestBody

    init(apiKey: String, endpoint: URL, requestBody: CompletionRequestBody) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.requestBody = requestBody
    }

    func callAsFunction() async throws -> (
        trunkStream: AsyncThrowingStream<CompletionStreamDataTrunk, Error>,
        cancel: Cancellable
    ) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (result, response) = try await URLSession.shared.bytes(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw ChatGPTServiceError.responseInvalid
        }
        
        guard response.statusCode == 200 else {
            let text = try await result.lines.reduce(into: "") { partialResult, current in
                partialResult += current
            }
            guard let data = text.data(using: .utf8)
            else { throw ChatGPTServiceError.responseInvalid }
            let decoder = JSONDecoder()
            let error = try? decoder.decode(ChatGPTError.self, from: data)
            throw error ?? ChatGPTServiceError.responseInvalid
        }

        return (
            AsyncThrowingStream<CompletionStreamDataTrunk, Error> { continuation in
                Task {
                    do {
                        for try await line in result.lines {
                            let prefix = "data: "
                            guard line.hasPrefix(prefix),
                                  let content = line.dropFirst(prefix.count).data(using: .utf8),
                                  let trunk = try? JSONDecoder()
                                  .decode(CompletionStreamDataTrunk.self, from: content)
                            else { continue }
                            continuation.yield(trunk)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            },
            Cancellable {
                result.task.cancel()
            }
        )
    }
}


