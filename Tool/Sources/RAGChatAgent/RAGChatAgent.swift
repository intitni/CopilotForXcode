import AIModel
import ChatBasic
import Foundation
import OpenAIService

public class RAGChatAgent: ChatAgent {
    public let configuration: RAGChatAgentConfiguration

    public init(configuration: RAGChatAgentConfiguration) {
        self.configuration = configuration
    }

    public func send(_ request: Request) async -> AsyncThrowingStream<Response, any Error> {
        let service = getService()
        let stream = AsyncThrowingStream<Response, any Error> { continuation in
            let task = Task(priority: .userInitiated) {
                do {
                    let response = try await service.send(content: request.text, summary: nil)
                    for try await item in response {
                        if Task.isCancelled {
                            continuation.finish()
                            return
                        }
                        continuation.yield(.contentToken(item))
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
        
        return stream
    }
}

extension RAGChatAgent {
    func getService() -> ChatGPTServiceType {
        fatalError()
    }
    
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

