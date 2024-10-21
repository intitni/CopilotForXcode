import Foundation

public struct ChatPluginRequest {
    public var text: String

    public init(text: String) {
        self.text = text
    }
}

public protocol ChatPlugin {
    typealias Response = ChatAgentResponse
    typealias Request = ChatPluginRequest
    static var id: String { get }
    static var command: String { get }
    static var name: String { get }
    func send(_ request: Request) async -> AsyncThrowingStream<Response, any Error>
}
