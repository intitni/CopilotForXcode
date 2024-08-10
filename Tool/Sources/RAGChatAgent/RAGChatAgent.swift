import AIModel
import ChatBasic
import Foundation
import OpenAIService

public struct ChatAgentConfiguration: Codable {
    public var capabilityIds: Set<String>
    public var temperature: Double?
    public var modelId: String?
    public var model: ChatModel?
    public var stop: [String]?
    public var maxTokens: Int?
    public var minimumReplyTokens: Int?
    public var runFunctionsAutomatically: Bool?
    public var apiKey: String?
}

public actor RAGChatAgent: ChatAgent {
    let configuration: ChatAgentConfiguration

    init(configuration: ChatAgentConfiguration) {
        self.configuration = configuration
    }

    public func send(_ request: Request) async -> AsyncThrowingStream<Response, any Error> {
        fatalError()
//        var continuation: AsyncThrowingStream<Response, any Error>.Continuation!
//        let stream = AsyncThrowingStream<Response, any Error> { cont in
//            continuation = cont
//        }
//        
//        await withTaskCancellationHandler {
//            <#code#>
//        } onCancel: {
//            continuation.finish(throwing: CancellationError())
//        }
//
//        return .init { continuation in
//            Task {
//                let response = try await chatGPTService.send(content: request.text, summary: nil)
//                continuation.finish()
//            }
//        }
    }
}

extension RAGChatAgent {
    var allCapabilities: [String: any RAGChatAgentCapability] {
        RAGChatAgentCapabilityContainer.capabilities
    }

    func capability(for identifier: String) -> (any RAGChatAgentCapability)? {
        allCapabilities[identifier]
    }
}

final class ChatFunctionProvider: ChatGPTFunctionProvider {
    var functions: [any ChatGPTFunction] = []

    init() {}

    func removeAll() {
        functions = []
    }

    func append(functions others: [any ChatGPTFunction]) {
        functions.append(contentsOf: others)
    }

    var functionCallStrategy: OpenAIService.FunctionCallStrategy? {
        nil
    }
}

