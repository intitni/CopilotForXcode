import ChatBasic
import ChatService
import ComposableArchitecture
import Foundation
import MarkdownUI
import OpenAIService
import Preferences
import Terminal

public struct DisplayedChatMessage: Equatable {
    public enum Role: Equatable {
        case user
        case assistant
        case tool
        case ignored
    }

    public struct Reference: Equatable {
        public typealias Kind = ChatMessage.Reference.Kind

        public var title: String
        public var subtitle: String
        public var uri: String
        public var startLine: Int?
        public var kind: Kind

        public init(
            title: String,
            subtitle: String,
            uri: String,
            startLine: Int?,
            kind: Kind
        ) {
            self.title = title
            self.subtitle = subtitle
            self.uri = uri
            self.startLine = startLine
            self.kind = kind
        }
    }

    public var id: String
    public var role: Role
    public var text: String
    public var markdownContent: MarkdownContent
    public var references: [Reference] = []

    public init(id: String, role: Role, text: String, references: [Reference]) {
        self.id = id
        self.role = role
        self.text = text
        markdownContent = .init(text)
        self.references = references
    }
}

private var isPreview: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}

@Reducer
struct Chat {
    public typealias MessageID = String

    @ObservableState
    struct State: Equatable {
        var title: String = "Chat"
        var typedMessage = ""
        var history: [DisplayedChatMessage] = []
        var isReceivingMessage = false
        var chatMenu = ChatMenu.State()
        var focusedField: Field?
        var isEnabled = true
        var isPinnedToBottom = true

        enum Field: String, Hashable {
            case textField
        }
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)

        case appear
        case refresh
        case setIsEnabled(Bool)
        case sendButtonTapped
        case returnButtonTapped
        case stopRespondingButtonTapped
        case clearButtonTap
        case deleteMessageButtonTapped(MessageID)
        case resendMessageButtonTapped(MessageID)
        case setAsExtraPromptButtonTapped(MessageID)
        case manuallyScrolledUp
        case scrollToBottomButtonTapped
        case focusOnTextField
        case referenceClicked(DisplayedChatMessage.Reference)

        case observeChatService
        case observeHistoryChange
        case observeIsReceivingMessageChange
        case observeSystemPromptChange
        case observeExtraSystemPromptChange
        case observeDefaultScopesChange

        case historyChanged
        case isReceivingMessageChanged
        case systemPromptChanged
        case extraSystemPromptChanged
        case defaultScopesChanged

        case chatMenu(ChatMenu.Action)
    }

    let service: ChatService
    let id = UUID()

    enum CancelID: Hashable {
        case observeHistoryChange(UUID)
        case observeIsReceivingMessageChange(UUID)
        case observeSystemPromptChange(UUID)
        case observeExtraSystemPromptChange(UUID)
        case observeDefaultScopesChange(UUID)
        case sendMessage(UUID)
    }

    @Dependency(\.openURL) var openURL

    var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.chatMenu, action: /Action.chatMenu) {
            ChatMenu(service: service)
        }

        Reduce { state, action in
            switch action {
            case .appear:
                return .run { send in
                    if isPreview { return }
                    await send(.observeChatService)
                    await send(.historyChanged)
                    await send(.isReceivingMessageChanged)
                    await send(.systemPromptChanged)
                    await send(.extraSystemPromptChanged)
                    await send(.focusOnTextField)
                    await send(.refresh)
                }

            case .refresh:
                return .run { send in
                    await send(.chatMenu(.refresh))
                }

            case let .setIsEnabled(isEnabled):
                state.isEnabled = isEnabled
                return .none

            case .sendButtonTapped:
                guard !state.typedMessage.isEmpty else { return .none }
                let message = state.typedMessage
                state.typedMessage = ""
                return .run { _ in
                    try await service.send(content: message)
                }.cancellable(id: CancelID.sendMessage(id))

            case .returnButtonTapped:
                state.typedMessage += "\n"
                return .none

            case .stopRespondingButtonTapped:
                return .merge(
                    .run { _ in
                        await service.stopReceivingMessage()
                    },
                    .cancel(id: CancelID.sendMessage(id))
                )

            case .clearButtonTap:
                return .run { _ in
                    await service.clearHistory()
                }

            case let .deleteMessageButtonTapped(id):
                return .run { _ in
                    await service.deleteMessage(id: id)
                }

            case let .resendMessageButtonTapped(id):
                return .run { _ in
                    try await service.resendMessage(id: id)
                }

            case let .setAsExtraPromptButtonTapped(id):
                return .run { _ in
                    await service.setMessageAsExtraPrompt(id: id)
                }

            case let .referenceClicked(reference):
                let fileURL = URL(fileURLWithPath: reference.uri)
                return .run { _ in
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        let terminal = Terminal()
                        do {
                            _ = try await terminal.runCommand(
                                "/bin/bash",
                                arguments: [
                                    "-c",
                                    "xed -l \(reference.startLine ?? 0) \"\(reference.uri)\"",
                                ],
                                environment: [:]
                            )
                        } catch {
                            print(error)
                        }
                    } else if let url = URL(string: reference.uri), url.scheme != nil {
                        await openURL(url)
                    }
                }

            case .manuallyScrolledUp:
                state.isPinnedToBottom = false
                return .none

            case .scrollToBottomButtonTapped:
                state.isPinnedToBottom = true
                return .none

            case .focusOnTextField:
                state.focusedField = .textField
                return .none

            case .observeChatService:
                return .run { send in
                    await send(.observeHistoryChange)
                    await send(.observeIsReceivingMessageChange)
                    await send(.observeSystemPromptChange)
                    await send(.observeExtraSystemPromptChange)
                    await send(.observeDefaultScopesChange)
                }

            case .observeHistoryChange:
                return .run { send in
                    let stream = AsyncStream<Void> { continuation in
                        let cancellable = service.$chatHistory.sink { _ in
                            continuation.yield()
                        }
                        continuation.onTermination = { _ in
                            cancellable.cancel()
                        }
                    }
                    let debouncedHistoryChange = TimedDebounceFunction(duration: 0.2) {
                        await send(.historyChanged)
                    }

                    for await _ in stream {
                        await debouncedHistoryChange()
                    }
                }.cancellable(id: CancelID.observeHistoryChange(id), cancelInFlight: true)

            case .observeIsReceivingMessageChange:
                return .run { send in
                    let stream = AsyncStream<Void> { continuation in
                        let cancellable = service.$isReceivingMessage
                            .sink { _ in
                                continuation.yield()
                            }
                        continuation.onTermination = { _ in
                            cancellable.cancel()
                        }
                    }
                    for await _ in stream {
                        await send(.isReceivingMessageChanged)
                    }
                }.cancellable(
                    id: CancelID.observeIsReceivingMessageChange(id),
                    cancelInFlight: true
                )

            case .observeSystemPromptChange:
                return .run { send in
                    let stream = AsyncStream<Void> { continuation in
                        let cancellable = service.$systemPrompt.sink { _ in
                            continuation.yield()
                        }
                        continuation.onTermination = { _ in
                            cancellable.cancel()
                        }
                    }
                    for await _ in stream {
                        await send(.systemPromptChanged)
                    }
                }.cancellable(id: CancelID.observeSystemPromptChange(id), cancelInFlight: true)

            case .observeExtraSystemPromptChange:
                return .run { send in
                    let stream = AsyncStream<Void> { continuation in
                        let cancellable = service.$extraSystemPrompt
                            .sink { _ in
                                continuation.yield()
                            }
                        continuation.onTermination = { _ in
                            cancellable.cancel()
                        }
                    }
                    for await _ in stream {
                        await send(.extraSystemPromptChanged)
                    }
                }.cancellable(id: CancelID.observeExtraSystemPromptChange(id), cancelInFlight: true)

            case .observeDefaultScopesChange:
                return .run { send in
                    let stream = AsyncStream<Void> { continuation in
                        let cancellable = service.$defaultScopes
                            .sink { _ in
                                continuation.yield()
                            }
                        continuation.onTermination = { _ in
                            cancellable.cancel()
                        }
                    }
                    for await _ in stream {
                        await send(.defaultScopesChanged)
                    }
                }.cancellable(id: CancelID.observeDefaultScopesChange(id), cancelInFlight: true)

            case .historyChanged:
                state.history = service.chatHistory.flatMap { message in
                    var all = [DisplayedChatMessage]()
                    all.append(.init(
                        id: message.id,
                        role: {
                            switch message.role {
                            case .system: return .ignored
                            case .user: return .user
                            case .assistant:
                                if let text = message.summary ?? message.content,
                                   !text.isEmpty
                                {
                                    return .assistant
                                }
                                return .ignored
                            }
                        }(),
                        text: message.summary ?? message.content ?? "",
                        references: message.references.map(convertReference)
                    ))

                    for call in message.toolCalls ?? [] {
                        all.append(.init(
                            id: message.id + call.id,
                            role: .tool,
                            text: call.response.summary ?? call.response.content,
                            references: []
                        ))
                    }

                    return all
                }

                state.title = {
                    let defaultTitle = "Chat"
                    guard let lastMessageText = state.history
                        .filter({ $0.role == .assistant || $0.role == .user })
                        .last?
                        .text else { return defaultTitle }
                    if lastMessageText.isEmpty { return defaultTitle }
                    let trimmed = lastMessageText
                        .trimmingCharacters(in: .punctuationCharacters)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.starts(with: "```") {
                        return "Code Block"
                    } else {
                        return trimmed
                    }
                }()
                return .none

            case .isReceivingMessageChanged:
                state.isReceivingMessage = service.isReceivingMessage
                if service.isReceivingMessage {
                    state.isPinnedToBottom = true
                }
                return .none

            case .systemPromptChanged:
                state.chatMenu.systemPrompt = service.systemPrompt
                return .none

            case .extraSystemPromptChanged:
                state.chatMenu.extraSystemPrompt = service.extraSystemPrompt
                return .none

            case .defaultScopesChanged:
                state.chatMenu.defaultScopes = service.defaultScopes
                return .none

            case .binding:
                return .none

            case .chatMenu:
                return .none
            }
        }
    }
}

@Reducer
struct ChatMenu {
    @ObservableState
    struct State: Equatable {
        var systemPrompt: String = ""
        var extraSystemPrompt: String = ""
        var temperatureOverride: Double? = nil
        var chatModelIdOverride: String? = nil
        var defaultScopes: Set<ChatService.Scope> = []
    }

    enum Action: Equatable {
        case appear
        case refresh
        case resetPromptButtonTapped
        case temperatureOverrideSelected(Double?)
        case chatModelIdOverrideSelected(String?)
        case customCommandButtonTapped(CustomCommand)
        case resetDefaultScopesButtonTapped
        case toggleScope(ChatService.Scope)
    }

    let service: ChatService

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appear:
                return .run {
                    await $0(.refresh)
                }

            case .refresh:
                state.temperatureOverride = service.configuration.overriding.temperature
                state.chatModelIdOverride = service.configuration.overriding.modelId
                return .none

            case .resetPromptButtonTapped:
                return .run { _ in
                    await service.resetPrompt()
                }
            case let .temperatureOverrideSelected(temperature):
                state.temperatureOverride = temperature
                return .run { _ in
                    service.configuration.overriding.temperature = temperature
                }
            case let .chatModelIdOverrideSelected(chatModelId):
                state.chatModelIdOverride = chatModelId
                return .run { _ in
                    service.configuration.overriding.modelId = chatModelId
                }
            case let .customCommandButtonTapped(command):
                return .run { _ in
                    try await service.handleCustomCommand(command)
                }

            case .resetDefaultScopesButtonTapped:
                return .run { _ in
                    service.resetDefaultScopes()
                }
            case let .toggleScope(scope):
                return .run { _ in
                    service.defaultScopes.formSymmetricDifference([scope])
                }
            }
        }
    }
}

private actor TimedDebounceFunction {
    let duration: TimeInterval
    let block: () async -> Void

    var task: Task<Void, Error>?
    var lastFireTime: Date = .init(timeIntervalSince1970: 0)

    init(duration: TimeInterval, block: @escaping () async -> Void) {
        self.duration = duration
        self.block = block
    }

    func callAsFunction() async {
        task?.cancel()
        if lastFireTime.timeIntervalSinceNow < -duration {
            await fire()
            task = nil
        } else {
            task = Task.detached { [weak self, duration] in
                try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                await self?.fire()
            }
        }
    }

    func fire() async {
        lastFireTime = Date()
        await block()
    }
}

private func convertReference(
    _ reference: ChatMessage.Reference
) -> DisplayedChatMessage.Reference {
    .init(
        title: reference.title,
        subtitle: {
            switch reference.kind {
            case let .symbol(_, uri, _, _):
                return uri
            case let .webpage(uri):
                return uri
            case let .textFile(uri):
                return uri
            case let .other(kind):
                return kind
            case .text:
                return reference.content
            }
        }(),
        uri: {
            switch reference.kind {
            case let .symbol(_, uri, _, _):
                return uri
            case let .webpage(uri):
                return uri
            case let .textFile(uri):
                return uri
            case .other:
                return ""
            case .text:
                return ""
            }
        }(),
        startLine: {
            switch reference.kind {
            case let .symbol(_, _, startLine, _):
                return startLine
            default:
                return nil
            }
        }(),
        kind: reference.kind
    )
}

