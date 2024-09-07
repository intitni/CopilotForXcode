import Foundation
import OpenAIService

public final class ContextAwareAutoManagedChatGPTMemory: ChatGPTMemory {
    private let memory: AutoManagedChatGPTMemory
    let contextController: DynamicContextController
    let functionProvider: ChatFunctionProvider
    weak var chatService: ChatService?

    public var history: [ChatMessage] {
        get async { await memory.history }
    }

    func observeHistoryChange(_ observer: @escaping () -> Void) {
        memory.observeHistoryChange(observer)
    }

    init(
        configuration: OverridingChatGPTConfiguration,
        functionProvider: ChatFunctionProvider
    ) {
        memory = AutoManagedChatGPTMemory(
            systemPrompt: "",
            configuration: configuration,
            functionProvider: functionProvider,
            maxNumberOfMessages: UserDefaults.shared.value(for: \.chatGPTMaxMessageCount)
        )
        contextController = DynamicContextController(
            memory: memory,
            functionProvider: functionProvider,
            configuration: configuration,
            contextCollectors: allContextCollectors
        )
        self.functionProvider = functionProvider
    }

    public func mutateHistory(_ update: (inout [ChatMessage]) -> Void) async {
        await memory.mutateHistory(update)
    }

    public func generatePrompt() async -> ChatGPTPrompt {
        let content = (await memory.history)
            .last(where: { $0.role == .user  })?.content
        try? await contextController.collectContextInformation(
            systemPrompt: """
            \(chatService?.systemPrompt ?? "")
            \(chatService?.extraSystemPrompt ?? "")
            """.trimmingCharacters(in: .whitespacesAndNewlines),
            content: content ?? ""
        )
        return await memory.generatePrompt()
    }
}

