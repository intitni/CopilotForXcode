import ChatContextCollector
import ChatPlugin
import Combine
import Foundation
import OpenAIService
import Preferences

public final class ChatService: ObservableObject {
    public let memory: AutoManagedChatGPTMemory
    public let configuration: OverridingChatGPTConfiguration<UserPreferenceChatGPTConfiguration>
    public let chatGPTService: any ChatGPTServiceType
    public var allPluginCommands: [String] { allPlugins.map { $0.command } }
    @Published public internal(set) var isReceivingMessage = false
    @Published public internal(set) var systemPrompt = UserDefaults.shared
        .value(for: \.defaultChatSystemPrompt)
    @Published public internal(set) var extraSystemPrompt = ""

    let pluginController: ChatPluginController
    let contextController: DynamicContextController
    let functionProvider: ChatFunctionProvider
    var cancellable = Set<AnyCancellable>()

    init<T: ChatGPTServiceType>(
        memory: AutoManagedChatGPTMemory,
        configuration: OverridingChatGPTConfiguration<UserPreferenceChatGPTConfiguration>,
        functionProvider: ChatFunctionProvider,
        chatGPTService: T
    ) {
        self.memory = memory
        self.configuration = configuration
        self.chatGPTService = chatGPTService
        self.functionProvider = functionProvider
        pluginController = ChatPluginController(
            chatGPTService: chatGPTService,
            plugins: allPlugins
        )
        contextController = DynamicContextController(
            memory: memory,
            functionProvider: functionProvider,
            contextCollectors: allContextCollectors
        )

        pluginController.chatService = self
    }

    public convenience init() {
        let configuration = UserPreferenceChatGPTConfiguration().overriding()
        let functionProvider = ChatFunctionProvider()
        let memory = AutoManagedChatGPTMemory(
            systemPrompt: "",
            configuration: configuration,
            functionProvider: functionProvider
        )
        self.init(
            memory: memory,
            configuration: configuration,
            functionProvider: functionProvider,
            chatGPTService: ChatGPTService(
                memory: memory,
                configuration: configuration,
                functionProvider: functionProvider
            )
        )

        memory.observeHistoryChange { [weak self] in
            self?.objectWillChange.send()
        }
    }

    public func send(content: String) async throws {
        guard !isReceivingMessage else { throw CancellationError() }
        let handledInPlugin = try await pluginController.handleContent(content)
        if handledInPlugin { return }
        try await contextController.updatePromptToMatchContent(systemPrompt: """
        \(systemPrompt)
        \(extraSystemPrompt)
        """, content: content)

        let stream = try await chatGPTService.send(content: content, summary: nil)
        isReceivingMessage = true
        do {
            for try await _ in stream {}
            isReceivingMessage = false
        } catch {
            isReceivingMessage = false
        }
    }
    
    public func sendAndWait(content: String) async throws -> String {
        try await send(content: content)
        if let reply = await memory.history.last(where: { $0.role == .assistant })?.content {
            return reply
        }
        return ""
    }

    public func stopReceivingMessage() async {
        await pluginController.stopResponding()
        await chatGPTService.stopReceivingMessage()
        isReceivingMessage = false

        // if it's stopped before the function finishes, remove the function call.
        await memory.mutateHistory { history in
            if history.last?.role == .assistant, history.last?.functionCall != nil {
                history.removeLast()
            }
        }
    }

    public func clearHistory() async {
        await pluginController.cancel()
        await memory.clearHistory()
        await chatGPTService.stopReceivingMessage()
        isReceivingMessage = false
    }

    public func resetPrompt() async {
        systemPrompt = UserDefaults.shared.value(for: \.defaultChatSystemPrompt)
        extraSystemPrompt = ""
    }

    public func deleteMessage(id: String) async {
        await memory.removeMessage(id)
    }

    public func resendMessage(id: String) async throws {
        if let message = (await memory.history).first(where: { $0.id == id }),
           let content = message.content
        {
            try await send(content: content)
        }
    }

    public func setMessageAsExtraPrompt(id: String) async {
        if let message = (await memory.history).first(where: { $0.id == id }),
           let content = message.content
        {
            mutateExtraSystemPrompt(content)
            await mutateHistory { history in
                history.append(.init(
                    role: .assistant,
                    content: "",
                    summary: "System prompt updated."
                ))
            }
        }
    }

    /// Setting it to `nil` to reset the system prompt
    public func mutateSystemPrompt(_ newPrompt: String?) {
        systemPrompt = newPrompt ?? UserDefaults.shared.value(for: \.defaultChatSystemPrompt)
    }

    public func mutateExtraSystemPrompt(_ newPrompt: String) {
        extraSystemPrompt = newPrompt
    }

    public func mutateHistory(_ mutator: @escaping (inout [ChatMessage]) -> Void) async {
        await memory.mutateHistory(mutator)
    }

    public func handleCustomCommand(_ command: CustomCommand) async throws {
        struct CustomCommandInfo {
            var specifiedSystemPrompt: String?
            var extraSystemPrompt: String?
            var sendingMessageImmediately: String?
            var name: String?
        }

        let info: CustomCommandInfo? = {
            switch command.feature {
            case let .chatWithSelection(extraSystemPrompt, prompt, useExtraSystemPrompt):
                let updatePrompt = useExtraSystemPrompt ?? true
                return .init(
                    extraSystemPrompt: updatePrompt ? extraSystemPrompt : nil,
                    sendingMessageImmediately: prompt,
                    name: command.name
                )
            case let .customChat(systemPrompt, prompt):
                return .init(
                    specifiedSystemPrompt: systemPrompt,
                    extraSystemPrompt: "",
                    sendingMessageImmediately: prompt,
                    name: command.name
                )
            case .promptToCode: return nil
            case .oneTimeDialog: return nil
            }
        }()

        guard let info else { return }

        let templateProcessor = CustomCommandTemplateProcessor()
        mutateSystemPrompt(info.specifiedSystemPrompt.map(templateProcessor.process))
        mutateExtraSystemPrompt(info.extraSystemPrompt.map(templateProcessor.process) ?? "")

        let customCommandPrefix = {
            if let name = info.name { return "[\(name)] " }
            return ""
        }()

        if info.specifiedSystemPrompt != nil || info.extraSystemPrompt != nil {
            await mutateHistory { history in
                history.append(.init(
                    role: .assistant,
                    content: "",
                    summary: "\(customCommandPrefix)System prompt is updated."
                ))
            }
        }

        if let sendingMessageImmediately = info.sendingMessageImmediately,
           !sendingMessageImmediately.isEmpty
        {
            try await send(content: templateProcessor.process(sendingMessageImmediately))
        }
    }
}

