import Foundation

public enum ChatAgentResponse {
    public enum Content {
        case text(String)
        case modification
    }
    
    /// Post the status of the current message.
    case status(String)
    /// Update the text message to the current message.
    case content([Content])
    /// Update the attachments of the current message.
    case attachments([URL])
    /// Update the references of the current message.
    case references([ChatMessage.Reference])
    /// End the current message. The next contents will be sent as a new message.
    case startNewMessage
}

public struct ChatAgentRequest {
    public var text: String
    public var history: [ChatMessage]
    public var extraContext: String

    public init(text: String, history: [ChatMessage], extraContext: String) {
        self.text = text
        self.history = history
        self.extraContext = extraContext
    }
}

public protocol ChatAgent {
    typealias Response = ChatAgentResponse
    typealias Request = ChatAgentRequest
    func send(_ request: Request) async -> AsyncThrowingStream<Response, any Error>
}

