import AsyncAlgorithms
import Foundation

public protocol ChatGPTServiceType {
    func send(content: String, summary: String?) async throws -> AsyncThrowingStream<String, Error>
    func stopReceivingMessage() async
    func restart() async
    func mutateSystemPrompt(_ newPrompt: String) async
}

public enum ChatGPTServiceError: Error {
    case endpointIncorrect
    case responseInvalid
}

public struct ChatGPTError: Error, Codable, LocalizedError {
    public var error: ErrorContent
    public init(error: ErrorContent) {
        self.error = error
    }

    public struct ErrorContent: Codable {
        public var message: String
        public var type: String
        public var param: String?
        public var code: String?

        public init(message: String, type: String, param: String? = nil, code: String? = nil) {
            self.message = message
            self.type = type
            self.param = param
            self.code = code
        }
    }

    public var errorDescription: String? {
        error.message
    }
}

public actor ChatGPTService: ChatGPTServiceType, ObservableObject {
    public var temperature: Double
    public var model: ChatGPTModel
    public var endpoint: String
    public var apiKey: String
    public var systemPrompt: String
    public var maxToken: Int
    public var history: [ChatGPTMessage] = [] {
        didSet { objectWillChange.send() }
    }

    public internal(set) var isReceivingMessage = false
    var ongoingTask: URLSessionDataTask?

    public init(
        systemPrompt: String,
        apiKey: String,
        endpoint: String = "https://api.openai.com/v1/chat/completions",
        model: ChatGPTModel = .gpt_3_5_turbo,
        temperature: Double = 1,
        maxToken: Int = 2048
    ) {
        self.systemPrompt = systemPrompt
        self.apiKey = apiKey
        self.model = model
        self.temperature = temperature
        self.maxToken = maxToken
        self.endpoint = endpoint
    }

    public func send(
        content: String,
        summary: String? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard !isReceivingMessage else { throw CancellationError() }
        guard let url = URL(string: endpoint) else { throw ChatGPTServiceError.endpointIncorrect }
        let newMessage = ChatGPTMessage(role: .user, content: content, summary: summary)
        history.append(newMessage)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let requestBody = ChatGPTRequest(
            model: model.rawValue,
            messages: combineHistoryWithSystemPrompt(),
            temperature: temperature,
            stream: true,
            max_tokens: maxToken
        )
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        isReceivingMessage = true
        
        do {
            let (result, response) = try await URLSession.shared.bytes(for: request)
            ongoingTask = result.task

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

            return AsyncThrowingStream<String, Error> { continuation in
                Task {
                    do {
                        for try await line in result.lines {
                            let prefix = "data: "
                            guard line.hasPrefix(prefix),
                                  let content = line.dropFirst(prefix.count).data(using: .utf8),
                                  let trunk = try? JSONDecoder()
                                  .decode(ChatGPTDataTrunk.self, from: content),
                                  let delta = trunk.choices.first?.delta
                            else { continue }

                            if history.last?.id == trunk.id {
                                if let role = delta.role {
                                    history[history.endIndex - 1].role = role
                                }
                                if let content = delta.content {
                                    history[history.endIndex - 1].content.append(content)
                                }
                            } else {
                                history.append(.init(
                                    role: delta.role ?? .assistant,
                                    content: delta.content ?? "",
                                    id: trunk.id
                                ))
                            }

                            if let content = delta.content {
                                continuation.yield(content)
                            }
                        }

                        continuation.finish()
                        isReceivingMessage = false
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
        } catch {
            isReceivingMessage = false
            throw error
        }
    }

    public func stopReceivingMessage() {
        ongoingTask?.cancel()
        ongoingTask = nil
        isReceivingMessage = false
    }

    public func restart() {
        history = []
    }

    public func mutateSystemPrompt(_ newPrompt: String) {
        systemPrompt = newPrompt
    }
}

extension ChatGPTService {
    func combineHistoryWithSystemPrompt() -> [ChatGPTMessage] {
        if history.count > 4 {
            return [.init(role: .system, content: systemPrompt)] +
                history[history.endIndex - 4..<history.endIndex]
        }
        return [.init(role: .system, content: systemPrompt)] + history
    }
}
