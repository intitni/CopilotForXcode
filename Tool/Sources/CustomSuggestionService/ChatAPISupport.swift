import AIModel
import Foundation
import JoinJSON
import Logger
import OpenAIService
import Preferences

/// Per-request options for chat models, resolved from preferences and the model's custom headers.
struct ChatAPIOptions {
    var api: OpenAIChatAPI
    var reasoningEffort: ReasoningEffort?
    var reasoningTokenBudget: Int
    var extraHeaders: [(name: String, value: String)]

    static func current(
        for model: ChatModel,
        apiKey: String,
        defaults: UserDefaultsType = UserDefaults.shared
    ) async -> ChatAPIOptions {
        let stored = ChatModelAPIOptions.stored(for: model.id, defaults: defaults)
        let parser = HeaderValueParser()
        var headers: [(name: String, value: String)] = []
        for field in model.info.customHeaderInfo.headers where !field.key.isEmpty {
            let value = await parser.parse(
                field.value,
                context: .init(
                    modelName: model.info.modelName,
                    apiKey: apiKey,
                    gitHubCopilotToken: { nil }
                )
            )
            headers.append((name: field.key, value: value))
        }
        return .init(
            api: stored.api,
            reasoningEffort: stored.reasoningEffort,
            reasoningTokenBudget: stored.reasoningTokenBudget,
            extraHeaders: CompletionHeader.validated(headers)
        )
    }
}

extension URLRequest {
    mutating func setExtraHeaders(_ headers: [(name: String, value: String)]) {
        for header in headers {
            setValue(header.value, forHTTPHeaderField: header.name)
        }
    }

    mutating func setOpenAIIdentityHeaders(organizationID: String, projectID: String) {
        if !organizationID.isEmpty {
            setValue(organizationID, forHTTPHeaderField: "OpenAI-Organization")
        }
        if !projectID.isEmpty {
            setValue(projectID, forHTTPHeaderField: "OpenAI-Project")
        }
    }
}

enum CompletionHeader {
    static func validated(
        _ headers: [(name: String, value: String)]
    ) -> [(name: String, value: String)] {
        headers.filter { header in
            if !isValidName(header.name) {
                Logger.service.error("Dropping invalid completion header name: \(header.name)")
                return false
            }
            if header.value.contains(where: \.isNewline) {
                Logger.service.error(
                    "Dropping completion header \(header.name) because the value contains a newline"
                )
                return false
            }
            return true
        }
    }

    /// Reject whitespace and control characters in header names.
    static func isValidName(_ name: String) -> Bool {
        !name.isEmpty && name.unicodeScalars.allSatisfy { scalar in
            scalar.value > 32 && scalar.value < 127
        }
    }
}

enum CompletionJSON {
    static func mergeCustomBody(_ data: Data, jsonBody: String) -> Data {
        let jsonBody = jsonBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !jsonBody.isEmpty else { return data }
        return JoinJSON().join(data, with: jsonBody)
    }
}

enum ReasoningTokenLimit {
    static func maxOutputTokens(maxToken: Int, effort: ReasoningEffort?, budget: Int) -> Int {
        if let effort, effort.addsReasoningTokenBudget {
            return maxToken + budget
        }
        return maxToken
    }
}

struct OrderedChatMessage {
    enum Role {
        case system
        case user
        case assistant
    }

    var role: Role
    var content: String
}

enum OrderedChatMessages {
    static func apply(
        _ messages: [OrderedChatMessage],
        requiresBeginWithUserMessage: Bool,
        enforceMessageOrder: Bool
    ) -> [OrderedChatMessage] {
        guard requiresBeginWithUserMessage || enforceMessageOrder else { return messages }
        var result = messages

        if requiresBeginWithUserMessage {
            if let firstUser = result.firstIndex(where: { $0.role == .user }) {
                let leading = result[..<firstUser]
                let systems = leading.filter { $0.role == .system }.map(\.content)
                    .filter { !$0.isEmpty }
                var rest = Array(result[firstUser...])
                if !systems.isEmpty {
                    rest[0].content = (systems + [rest[0].content])
                        .filter { !$0.isEmpty }
                        .joined(separator: "\n\n")
                }
                result = rest
            }
        }

        if enforceMessageOrder {
            var systems: [String] = []
            var others: [OrderedChatMessage] = []
            for message in result {
                switch message.role {
                case .system:
                    if !message.content.isEmpty { systems.append(message.content) }
                case .user, .assistant:
                    if let last = others.last, last.role == message.role {
                        others[others.endIndex - 1].content += "\n\n" + message.content
                    } else {
                        others.append(message)
                    }
                }
            }
            result = []
            if !systems.isEmpty {
                result.append(.init(role: .system, content: systems.joined(separator: "\n\n")))
            }
            result += others
        }

        return result
    }
}

enum CompletionStopWords {
    /// Truncates `text` at the first stop word. Returns nil when none appear.
    static func truncatedPrefix(of text: String, stopWords: [String]) -> String? {
        var earliest: String.Index?
        for word in stopWords where !word.isEmpty {
            if let range = text.range(of: word),
               earliest == nil || range.lowerBound < earliest!
            {
                earliest = range.lowerBound
            }
        }
        guard let earliest else { return nil }
        return String(text[..<earliest])
    }

    /// `text` without the longest trailing fragment that is a proper prefix of a stop word, so a
    /// streaming display never shows the beginning of a marker such as `</Code3721>`.
    static func displayablePrefix(of text: String, stopWords: [String]) -> String {
        var cut = 0
        for word in stopWords where word.count > 1 {
            for length in stride(from: word.count - 1, through: 1, by: -1) where length > cut {
                if text.hasSuffix(word.prefix(length)) {
                    cut = length
                    break
                }
            }
        }
        return cut == 0 ? text : String(text.dropLast(cut))
    }
}

/// Helpers for `text/event-stream` lines.
enum SSELine {
    /// The payload of a stream line, or nil for lines that carry no data
    /// (blank lines, `event:` / `id:` / `retry:` lines and comments).
    static func payload(of line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        for prefix in [":", "event:", "id:", "retry:"] where trimmed.hasPrefix(prefix) {
            return nil
        }
        if trimmed.hasPrefix("data:") {
            return String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        }
        return trimmed
    }
}

/// Shared HTTP handling for completion `URLSession.bytes` calls.
enum CompletionHTTP {
    static func collectBody(_ bytes: URLSession.AsyncBytes) async throws -> String {
        try await bytes.lines.reduce(into: "") { partial, line in
            if !partial.isEmpty { partial += "\n" }
            partial += line
        }
    }

    static func isEventStream(_ response: HTTPURLResponse) -> Bool {
        contentType(response).localizedCaseInsensitiveContains("text/event-stream")
    }

    static func isNDJSON(_ response: HTTPURLResponse) -> Bool {
        contentType(response).localizedCaseInsensitiveContains("ndjson")
    }

    /// Pretty-printed JSON is multiple lines and must not go through `ResponseStream`.
    /// Ollama streams NDJSON, which is also line-based.
    static func shouldParseAsSingleBody(_ response: HTTPURLResponse) -> Bool {
        !isEventStream(response) && !isNDJSON(response)
    }

    static func statusMessage(code: Int, body: String) -> String {
        "HTTP \(code): \(String(body.prefix(200)))"
    }

    static func parseFailureMessage(url: URL) -> String {
        "Cannot parse response from \(url.absoluteString)"
    }

    static func invalidResponseMessage() -> String {
        "The server returned an invalid response."
    }

    static func makeStream<Chunk>(
        result: URLSession.AsyncBytes,
        response: URLResponse,
        mapError: (String) -> Swift.Error,
        parseBody: (String) throws -> Chunk,
        parseLine: @escaping (String) throws -> ResponseStream<Chunk>.LineContent
    ) async throws -> ResponseStream<Chunk> {
        guard let http = response as? HTTPURLResponse else {
            throw mapError(invalidResponseMessage())
        }
        if http.statusCode != 200 {
            let body = try await collectBody(result)
            throw mapError(statusMessage(code: http.statusCode, body: body))
        }
        if shouldParseAsSingleBody(http) {
            let body = try await collectBody(result)
            return ResponseStream(single: try parseBody(body))
        }
        return ResponseStream(result: result, lineExtractor: parseLine)
    }

    private static func contentType(_ response: HTTPURLResponse) -> String {
        response.value(forHTTPHeaderField: "Content-Type") ?? ""
    }
}

enum APIErrorPayload {
    struct Envelope: Decodable {
        struct Body: Decodable {
            var message: String
            var type: String?
            var code: String?
        }

        var error: Body
    }

    static func message(in payload: String) -> String? {
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: Data(payload.utf8))
        else { return nil }
        return envelope.error.message
    }
}
