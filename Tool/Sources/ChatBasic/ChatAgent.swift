import Foundation

public enum ChatAgentResponse {
    public enum Content {
        case text(String)
    }

    public enum ActionResult {
        case success(String)
        case failure(String)
    }

    /// Post the status of the current message.
    case status([String])
    /// Stream the content to the current message.
    case content(Content)
    /// Update the attachments of the current message.
    case attachments([URL])
    /// start a new action.
    case startAction(id: String, task: String)
    /// Finish the current action.
    case finishAction(id: String, result: ActionResult)
    /// Update the references of the current message.
    case references([ChatMessage.Reference])
    /// End the current message. The next contents will be sent as a new message.
    case startNewMessage
    /// Reasoning
    case reasoning(String)
}

public struct ChatAgentRequest {
    public var text: String
    public var history: [ChatMessage]
    public var references: [ChatMessage.Reference]
    public var topics: [ChatMessage.Reference]

    public init(
        text: String,
        history: [ChatMessage],
        references: [ChatMessage.Reference],
        topics: [ChatMessage.Reference]
    ) {
        self.text = text
        self.history = history
        self.references = references
        self.topics = topics
    }
}

public protocol ChatAgent {
    typealias Response = ChatAgentResponse
    typealias Request = ChatAgentRequest
    /// Send a request to the agent.
    func send(_ request: Request) async -> AsyncThrowingStream<Response, any Error>
}

public extension AsyncThrowingStream<ChatAgentResponse, any Error> {
    func asTexts() async throws -> [String] {
        var result = [String]()
        var text = ""
        for try await response in self {
            switch response {
            case let .content(.text(content)):
                text += content
            case .startNewMessage:
                if !text.isEmpty {
                    result.append(text)
                    text = ""
                }
            default:
                break
            }
        }
        if !text.isEmpty {
            result.append(text)
        }
        return result
    }
}

