import AppKit
import Combine
import ComposableArchitecture
import MarkdownUI
import OpenAIService
import SharedUIComponents
import SwiftUI

private let r: Double = 8

public struct ChatPanel: View {
    let chat: StoreOf<Chat>
    @Namespace var inputAreaNamespace

    public var body: some View {
        VStack(spacing: 0) {
            ChatPanelMessages(chat: chat)
            Divider()
            ChatPanelInputArea(chat: chat)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { chat.send(.appear) }
    }
}

private struct ScrollViewOffsetPreferenceKey: PreferenceKey {
    static var defaultValue = CGFloat.zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

private struct ListHeightPreferenceKey: PreferenceKey {
    static var defaultValue = CGFloat.zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

struct ChatPanelMessages: View {
    let chat: StoreOf<Chat>
    @State var cancellable = Set<AnyCancellable>()
    @State var isScrollToBottomButtonDisplayed = true
    @Namespace var bottomID
    @Namespace var topID
    @Namespace var scrollSpace
    @State var scrollOffset: Double = 0
    @State var listHeight: Double = 0
    @State var didScrollToBottomOnAppearOnce = false
    @State var isBottomHidden = true
    @Environment(\.isEnabled) var isEnabled

    var body: some View {
        WithPerceptionTracking {
            ScrollViewReader { proxy in
                GeometryReader { listGeo in
                    List {
                        Group {
                            Spacer(minLength: 12)
                                .id(topID)

                            Instruction(chat: chat)

                            ChatHistory(chat: chat)
                                .listItemTint(.clear)

                            ExtraSpacingInResponding(chat: chat)

                            Spacer(minLength: 12)
                                .id(bottomID)
                                .onAppear {
                                    isBottomHidden = false
                                    if !didScrollToBottomOnAppearOnce {
                                        proxy.scrollTo(bottomID, anchor: .bottom)
                                        didScrollToBottomOnAppearOnce = true
                                    }
                                }
                                .onDisappear {
                                    isBottomHidden = true
                                }
                                .background(GeometryReader { geo in
                                    let offset = geo.frame(in: .named(scrollSpace)).minY
                                    Color.clear.preference(
                                        key: ScrollViewOffsetPreferenceKey.self,
                                        value: offset
                                    )
                                })
                        }
                        .modify { view in
                            if #available(macOS 13.0, *) {
                                view
                                    .listRowSeparator(.hidden)
                                    .listSectionSeparator(.hidden)
                            } else {
                                view
                            }
                        }
                    }
                    .listStyle(.plain)
                    .listRowBackground(EmptyView())
                    .modify { view in
                        if #available(macOS 13.0, *) {
                            view.scrollContentBackground(.hidden)
                        } else {
                            view
                        }
                    }
                    .coordinateSpace(name: scrollSpace)
                    .preference(
                        key: ListHeightPreferenceKey.self,
                        value: listGeo.size.height
                    )
                    .onPreferenceChange(ListHeightPreferenceKey.self) { value in
                        listHeight = value
                        updatePinningState()
                    }
                    .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { value in
                        scrollOffset = value
                        updatePinningState()
                    }
                    .overlay(alignment: .bottom) {
                        StopRespondingButton(chat: chat)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        scrollToBottomButton(proxy: proxy)
                    }
                    .background {
                        PinToBottomHandler(chat: chat, isBottomHidden: isBottomHidden) {
                            proxy.scrollTo(bottomID, anchor: .bottom)
                        }
                    }
                    .onAppear {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                    .task {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                trackScrollWheel()
            }
            .onDisappear {
                cancellable.forEach { $0.cancel() }
                cancellable = []
            }
            .onChange(of: isEnabled) { isEnabled in
                chat.send(.setIsEnabled(isEnabled))
            }
        }
    }

    func trackScrollWheel() {
        NSApplication.shared.publisher(for: \.currentEvent)
            .receive(on: DispatchQueue.main)
            .filter { [chat] in
                guard chat.withState(\.isEnabled) else { return false }
                return $0?.type == .scrollWheel
            }
            .compactMap { $0 }
            .sink { event in
                guard chat.withState(\.isPinnedToBottom) else { return }
                let delta = event.deltaY
                let scrollUp = delta > 0
                if scrollUp {
                    chat.send(.manuallyScrolledUp)
                }
            }
            .store(in: &cancellable)
    }

    @MainActor
    func updatePinningState() {
        // where does the 32 come from?
        withAnimation(.linear(duration: 0.1)) {
            isScrollToBottomButtonDisplayed = scrollOffset > listHeight + 32 + 20
                || scrollOffset <= 0
        }
    }

    @ViewBuilder
    func scrollToBottomButton(proxy: ScrollViewProxy) -> some View {
        Button(action: {
            chat.send(.scrollToBottomButtonTapped)
            withAnimation(.easeInOut(duration: 0.1)) {
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
        }) {
            Image(systemName: "arrow.down")
                .padding(4)
                .background {
                    Circle()
                        .fill(.thickMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 2)
                }
                .overlay {
                    Circle().stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }
                .foregroundStyle(.secondary)
                .padding(4)
        }
        .keyboardShortcut(.downArrow, modifiers: [.command])
        .opacity(isScrollToBottomButtonDisplayed ? 1 : 0)
        .buttonStyle(.plain)
    }

    struct ExtraSpacingInResponding: View {
        let chat: StoreOf<Chat>

        var body: some View {
            WithPerceptionTracking {
                if chat.isReceivingMessage {
                    Spacer(minLength: 12)
                }
            }
        }
    }

    struct PinToBottomHandler: View {
        let chat: StoreOf<Chat>
        let isBottomHidden: Bool
        let scrollToBottom: () -> Void

        @State var isInitialLoad = true

        var body: some View {
            WithPerceptionTracking {
                EmptyView()
                    .onChange(of: chat.isReceivingMessage) { isReceiving in
                        if isReceiving {
                            Task {
                                await Task.yield()
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    scrollToBottom()
                                }
                            }
                        }
                    }
                    .onChange(of: chat.history.last) { _ in
                        if chat.withState(\.isPinnedToBottom) || isInitialLoad {
                            if isInitialLoad {
                                isInitialLoad = false
                            }
                            Task {
                                await Task.yield()
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    scrollToBottom()
                                }
                            }
                        }
                    }
                    .onChange(of: isBottomHidden) { value in
                        // This is important to prevent it from jumping to the top!
                        if value, chat.withState(\.isPinnedToBottom) {
                            scrollToBottom()
                        }
                    }
            }
        }
    }
}

struct ChatHistory: View {
    let chat: StoreOf<Chat>

    var body: some View {
        WithPerceptionTracking {
            ForEach(chat.history, id: \.id) { message in
                WithPerceptionTracking {
                    ChatHistoryItem(chat: chat, message: message).id(message.id)
                }
            }
        }
    }
}

struct ChatHistoryItem: View {
    let chat: StoreOf<Chat>
    let message: DisplayedChatMessage

    var body: some View {
        WithPerceptionTracking {
            let text = message.text
            let markdownContent = message.markdownContent
            switch message.role {
            case .user:
                UserMessage(
                    id: message.id,
                    text: text,
                    markdownContent: markdownContent,
                    chat: chat
                )
                .listRowInsets(EdgeInsets(
                    top: 0,
                    leading: -8,
                    bottom: 0,
                    trailing: -8
                ))
                .padding(.vertical, 4)
            case .assistant:
                BotMessage(
                    id: message.id,
                    text: text,
                    markdownContent: markdownContent,
                    references: message.references,
                    chat: chat
                )
                .listRowInsets(EdgeInsets(
                    top: 0,
                    leading: -8,
                    bottom: 0,
                    trailing: -8
                ))
                .padding(.vertical, 4)
            case .tool:
                FunctionMessage(id: message.id, text: text)
            case .ignored:
                EmptyView()
            }
        }
    }
}

private struct StopRespondingButton: View {
    let chat: StoreOf<Chat>

    var body: some View {
        WithPerceptionTracking {
            if chat.isReceivingMessage {
                Button(action: {
                    chat.send(.stopRespondingButtonTapped)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                        Text("Stop Responding")
                    }
                    .padding(8)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: r, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: r, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    }
                }
                .buttonStyle(.borderless)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 8)
                .opacity(chat.isReceivingMessage ? 1 : 0)
                .disabled(!chat.isReceivingMessage)
                .transformEffect(.init(
                    translationX: 0,
                    y: chat.isReceivingMessage ? 0 : 20
                ))
            }
        }
    }
}

struct ChatPanelInputArea: View {
    let chat: StoreOf<Chat>
    @FocusState var focusedField: Chat.State.Field?

    var body: some View {
        HStack {
            clearButton
            InputAreaTextEditor(chat: chat, focusedField: $focusedField)
        }
        .padding(8)
        .background(.ultraThickMaterial)
    }

    @MainActor
    var clearButton: some View {
        Button(action: {
            chat.send(.clearButtonTap)
        }) {
            Group {
                if #available(macOS 13.0, *) {
                    Image(systemName: "eraser.line.dashed.fill")
                } else {
                    Image(systemName: "trash.fill")
                }
            }
            .padding(6)
            .background {
                Circle().fill(Color(nsColor: .controlBackgroundColor))
            }
            .overlay {
                Circle().stroke(Color(nsColor: .controlColor), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    struct InputAreaTextEditor: View {
        @Perception.Bindable var chat: StoreOf<Chat>
        var focusedField: FocusState<Chat.State.Field?>.Binding

        var body: some View {
            WithPerceptionTracking {
                HStack(spacing: 0) {
                    AutoresizingCustomTextEditor(
                        text: $chat.typedMessage,
                        font: .systemFont(ofSize: 14),
                        isEditable: true,
                        maxHeight: 400,
                        onSubmit: { chat.send(.sendButtonTapped) },
                        completions: chatAutoCompletion
                    )
                    .focused(focusedField, equals: .textField)
                    .bind($chat.focusedField, to: focusedField)
                    .padding(8)
                    .fixedSize(horizontal: false, vertical: true)

                    Button(action: {
                        chat.send(.sendButtonTapped)
                    }) {
                        Image(systemName: "paperplane.fill")
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(chat.isReceivingMessage)
                    .keyboardShortcut(KeyEquivalent.return, modifiers: [])
                }
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .controlColor), lineWidth: 1)
                }
                .background {
                    Button(action: {
                        chat.send(.returnButtonTapped)
                    }) {
                        EmptyView()
                    }
                    .keyboardShortcut(KeyEquivalent.return, modifiers: [.shift])

                    Button(action: {
                        focusedField.wrappedValue = .textField
                    }) {
                        EmptyView()
                    }
                    .keyboardShortcut("l", modifiers: [.command])
                }
            }
        }

        func chatAutoCompletion(text: String, proposed: [String], range: NSRange) -> [String] {
            guard text.count == 1 else { return [] }
            let plugins = [String]() // chat.pluginIdentifiers.map { "/\($0)" }
            let availableFeatures = plugins + [
                "/exit",
                "@code",
                "@sense",
                "@project",
                "@web",
            ]

            let result: [String] = availableFeatures
                .filter { $0.hasPrefix(text) && $0 != text }
                .compactMap {
                    guard let index = $0.index(
                        $0.startIndex,
                        offsetBy: range.location,
                        limitedBy: $0.endIndex
                    ) else { return nil }
                    return String($0[index...])
                }
            return result
        }
    }
}

// MARK: - Previews

struct ChatPanel_Preview: PreviewProvider {
    static let history: [DisplayedChatMessage] = [
        .init(
            id: "1",
            role: .user,
            text: "**Hello**",
            references: []
        ),
        .init(
            id: "2",
            role: .assistant,
            text: """
            ```swift
            func foo() {}
            ```
            **Hey**! What can I do for you?**Hey**! What can I do for you?**Hey**! What can I do for you?**Hey**! What can I do for you?
            """,
            references: [
                .init(
                    title: "Hello Hello Hello Hello",
                    subtitle: "Hi Hi Hi Hi",
                    uri: "https://google.com",
                    startLine: nil,
                    kind: .symbol(.class, uri: "https://google.com", startLine: nil, endLine: nil)
                ),
            ]
        ),
        .init(
            id: "7",
            role: .ignored,
            text: "Ignored",
            references: []
        ),
        .init(
            id: "6",
            role: .tool,
            text: """
            Searching for something...
            - abc
            - [def](https://1.com)
            > hello
            > hi
            """,
            references: []
        ),
        .init(
            id: "5",
            role: .assistant,
            text: "Yooo",
            references: []
        ),
        .init(
            id: "4",
            role: .user,
            text: "Yeeeehh",
            references: []
        ),
        .init(
            id: "3",
            role: .user,
            text: #"""
            Please buy me a coffee!
            | Coffee | Milk |
            |--------|------|
            | Espresso | No |
            | Latte | Yes |

            ```swift
            func foo() {}
            ```
            ```objectivec
            - (void)bar {}
            ```
            """#,
            references: []
        ),
    ]

    static var previews: some View {
        ChatPanel(chat: .init(
            initialState: .init(history: ChatPanel_Preview.history, isReceivingMessage: true),
            reducer: { Chat(service: .init()) }
        ))
        .frame(width: 450, height: 1200)
        .colorScheme(.dark)
    }
}

struct ChatPanel_EmptyChat_Preview: PreviewProvider {
    static var previews: some View {
        ChatPanel(chat: .init(
            initialState: .init(history: [DisplayedChatMessage](), isReceivingMessage: false),
            reducer: { Chat(service: .init()) }
        ))
        .padding()
        .frame(width: 450, height: 600)
        .colorScheme(.dark)
    }
}

struct ChatPanel_InputText_Preview: PreviewProvider {
    static var previews: some View {
        ChatPanel(chat: .init(
            initialState: .init(history: ChatPanel_Preview.history, isReceivingMessage: false),
            reducer: { Chat(service: .init()) }
        ))
        .padding()
        .frame(width: 450, height: 600)
        .colorScheme(.dark)
    }
}

struct ChatPanel_InputMultilineText_Preview: PreviewProvider {
    static var previews: some View {
        ChatPanel(
            chat: .init(
                initialState: .init(
                    typedMessage: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Fusce turpis dolor, malesuada quis fringilla sit amet, placerat at nunc. Suspendisse orci tortor, tempor nec blandit a, malesuada vel tellus. Nunc sed leo ligula. Ut at ligula eget turpis pharetra tristique. Integer luctus leo non elit rhoncus fermentum.",

                    history: ChatPanel_Preview.history,
                    isReceivingMessage: false
                ),
                reducer: { Chat(service: .init()) }
            )
        )
        .padding()
        .frame(width: 450, height: 600)
        .colorScheme(.dark)
    }
}

struct ChatPanel_Light_Preview: PreviewProvider {
    static var previews: some View {
        ChatPanel(chat: .init(
            initialState: .init(history: ChatPanel_Preview.history, isReceivingMessage: true),
            reducer: { Chat(service: .init()) }
        ))
        .padding()
        .frame(width: 450, height: 600)
        .colorScheme(.light)
    }
}

