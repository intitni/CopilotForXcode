import Foundation

public struct ChatPluginRequest {
    public var text: String
    public var arguments: [String]
    public var history: [ChatMessage]

    public init(text: String, arguments: [String], history: [ChatMessage]) {
        self.text = text
        self.arguments = arguments
        self.history = history
    }
}

public protocol ChatPlugin {
    typealias Response = ChatAgentResponse
    typealias Request = ChatPluginRequest
    static var id: String { get }
    static var command: String { get }
    static var name: String { get }
    static var description: String { get }
    func send(_ request: Request) async -> AsyncThrowingStream<Response, any Error>
    func formatContent(_ content: Response.Content) -> Response.Content
    init()
}

public extension ChatPlugin {
    func formatContent(_ content: Response.Content) -> Response.Content {
        return content
    }
}

