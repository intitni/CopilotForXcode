import Foundation

public struct ChatPluginRequest: Sendable {
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
    // In this method, the plugin is able to send more complicated response. It also enables it to
    // perform special tasks like starting a new message or reporting progress.
    func sendForComplicatedResponse(
        _ request: Request
    ) async -> AsyncThrowingStream<Response, any Error>
    // This method allows the plugin to respond a stream of text content only.
    func sendForTextResponse(_ request: Request) async -> AsyncThrowingStream<String, any Error>
    func formatContent(_ content: Response.Content) -> Response.Content
    init()
}

public extension ChatPlugin {
    func formatContent(_ content: Response.Content) -> Response.Content {
        return content
    }
    
    func sendForComplicatedResponse(
        _ request: Request
    ) async -> AsyncThrowingStream<Response, any Error> {
        let textStream = await sendForTextResponse(request)
        return AsyncThrowingStream<Response, any Error> { continuation in
            let task = Task {
                do {
                    for try await text in textStream {
                        continuation.yield(Response.content(.text(text)))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
