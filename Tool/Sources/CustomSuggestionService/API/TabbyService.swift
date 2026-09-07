import CopilotForXcodeKit
import Foundation
import AIModel

actor TabbyService {
    enum AuthorizationMode {
        case none
        case bearerToken(String)
        case basic(username: String, password: String)
        case customHeaderField(name: String, value: String)
    }

    let url: URL
    let temperature: Double
    let authorizationMode: AuthorizationMode

    init(
        url: String? = nil,
        temperature: Double = 0.2,
        authorizationMode: AuthorizationMode
    ) {
        self.url = url
            .flatMap(URL.init(string:)) ?? URL(string: "http://127.0.0.1:8080/v1/completions")!
        self.temperature = temperature
        self.authorizationMode = authorizationMode
    }
}

extension TabbyService: CodeCompletionServiceType {
    func getCompletion(_ request: PromptStrategy) async throws -> AsyncStream<String> {
        let prefix = request.prefix.joined()
        let suffix = request.suffix.joined()
        let requestBody = RequestBody(
            language: request.language?.rawValue,
            segments: .init(
                prefix: prefix,
                suffix: suffix,
                clipboard: ""
            ),
            temperature: temperature,
            seed: nil
        )
        CodeCompletionLogger.logger.logPrompt([
            (prefix, "prefix"),
            (suffix, "suffix"),
        ])
        return AsyncStream<String> { continuation in
            let task = Task {
                let result = try await send(requestBody)
                try Task.checkCancellation()
                continuation.yield(result)
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

extension TabbyService {
    enum Error: Swift.Error, LocalizedError {
        case serverError(String)
        case decodeError(Swift.Error)

        var errorDescription: String? {
            switch self {
            case let .serverError(message):
                return "Server returned an error: \(message)"
            case let .decodeError(error):
                return "Failed to decode response body: \(error)"
            }
        }
    }

    struct RequestBody: Codable {
        struct Segments: Codable {
            var prefix: String
            var suffix: String
            var clipboard: String
        }

        var language: String?
        var segments: Segments
        var temperature: Double
        var seed: Int?
    }

    struct ResponseBody: Codable {
        struct Choice: Codable {
            var index: Int
            var text: String
        }

        var id: String
        var choices: [Choice]
    }

    func send(_ requestBody: RequestBody) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        switch authorizationMode {
        case let .basic(username, password):
            let data = "\(username):\(password)".data(using: .utf8)!
            let base64 = data.base64EncodedString()
            request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
        case let .bearerToken(token):
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case let .customHeaderField(name, value):
            request.setValue(value, forHTTPHeaderField: name)
        case .none:
            break
        }

        let (result, response) = try await URLSession.shared.data(for: request)

        guard let response = response as? HTTPURLResponse else {
            throw CancellationError()
        }

        guard response.statusCode == 200 else {
            throw Error.serverError(String(data: result, encoding: .utf8) ?? "Unknown Error")
        }

        do {
            let body = try JSONDecoder().decode(ResponseBody.self, from: result)
            return body.choices.first?.text ?? ""
        } catch {
            dump(error)
            throw Error.decodeError(error)
        }
    }
}

