import AIModel
import AsyncAlgorithms
import ChatBasic
import Dependencies
import Foundation
import IdentifiedCollections
import Preferences

@available(*, deprecated, message: "Use ChatGPTServiceType instead.")
public protocol LegacyChatGPTServiceType {
    var memory: ChatGPTMemory { get set }
    var configuration: ChatGPTConfiguration { get set }
    func send(content: String, summary: String?) async throws -> AsyncThrowingStream<String, Error>
    func stopReceivingMessage() async
}

@available(*, deprecated, message: "Use ChatGPTServiceType instead.")
public class LegacyChatGPTService: LegacyChatGPTServiceType {
    public var memory: ChatGPTMemory
    public var configuration: ChatGPTConfiguration
    public var functionProvider: ChatGPTFunctionProvider

    var runningTask: Task<AsyncThrowingStream<String, any Error>, Never>?

    public init(
        memory: ChatGPTMemory = AutoManagedChatGPTMemory(
            systemPrompt: "",
            configuration: UserPreferenceChatGPTConfiguration(),
            functionProvider: NoChatGPTFunctionProvider(), 
            maxNumberOfMessages: .max
        ),
        configuration: ChatGPTConfiguration = UserPreferenceChatGPTConfiguration(),
        functionProvider: ChatGPTFunctionProvider = NoChatGPTFunctionProvider()
    ) {
        self.memory = memory
        self.configuration = configuration
        self.functionProvider = functionProvider
    }

    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date
    @Dependency(\.chatCompletionsAPIBuilder) var chatCompletionsAPIBuilder

    /// Send a message and stream the reply.
    public func send(
        content: String,
        summary: String? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
        let task = Task {
            if !content.isEmpty || summary != nil {
                let newMessage = ChatMessage(
                    id: uuid().uuidString,
                    role: .user,
                    content: content,
                    name: nil,
                    toolCalls: nil,
                    summary: summary,
                    references: []
                )
                await memory.appendMessage(newMessage)
            }
            
            let service = ChatGPTService(
                configuration: configuration,
                functionProvider: functionProvider
            )
            
            let responses = service.send(memory)
            
            return responses.compactMap { response in
                switch response {
                case let .partialText(token): return token
                default: return nil
                }
            }.eraseToThrowingStream()
        }
        runningTask = task
        return await task.value
    }

    /// Send a message and get the reply in return.
    public func sendAndWait(
        content: String,
        summary: String? = nil
    ) async throws -> String? {
        if !content.isEmpty || summary != nil {
            let newMessage = ChatMessage(
                id: uuid().uuidString,
                role: .user,
                content: content,
                summary: summary
            )
            await memory.appendMessage(newMessage)
        }

        let service = ChatGPTService(
            configuration: configuration,
            functionProvider: functionProvider
        )

        return try await service.send(memory).asText()
    }

    public func stopReceivingMessage() {
        runningTask?.cancel()
    }
}

