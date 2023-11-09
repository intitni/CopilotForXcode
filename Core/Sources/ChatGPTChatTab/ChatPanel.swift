import AppKit
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
        .background(.regularMaterial)
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
    @State var isScrollToBottomButtonDisplayed = true
    @State var isPinnedToBottom = true
    @Namespace var bottomID
    @Namespace var scrollSpace
    @State var scrollOffset: Double = 0
    @State var listHeight: Double = 0

    var body: some View {
        ScrollViewReader { proxy in
            GeometryReader { listGeo in
                List {
                    Group {
                        Spacer(minLength: 12)

                        Instruction(chat: chat)

                        ChatHistory(chat: chat)
                            .listItemTint(.clear)

                        WithViewStore(chat, observe: \.isReceivingMessage) { viewStore in
                            if viewStore.state {
                                Spacer(minLength: 12)
                            }
                        }

                        Spacer(minLength: 12)
                            .id(bottomID)
                            .onAppear {
                                proxy.scrollTo(bottomID, anchor: .bottom)
                            }
                            .task {
                                proxy.scrollTo(bottomID, anchor: .bottom)
                            }
                            .background(GeometryReader { geo in
                                let offset = geo.frame(in: .named(scrollSpace)).minY
                                Color.clear.preference(
                                    key: ScrollViewOffsetPreferenceKey.self,
                                    value: offset
                                )
                            })
                            .preference(
                                key: ListHeightPreferenceKey.self,
                                value: listGeo.size.height
                            )
                    }
                    .modify { view in
                        if #available(macOS 13.0, *) {
                            view.listRowSeparator(.hidden).listSectionSeparator(.hidden)
                        } else {
                            view
                        }
                    }
                }
                .listStyle(.plain)
                .coordinateSpace(name: scrollSpace)
                .onPreferenceChange(ListHeightPreferenceKey.self) { value in
                    listHeight = value
                    updatePinningState()
                }
                .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { value in
                    /// I don't know if there is a way to detect that a scroll is triggered by user
                    let scrollUpToThreshold = listHeight > 0 // sometimes it can suddenly become 0
                        && value > listHeight + 32 + 20 // scroll up to a threshold
                        && value > scrollOffset // it's scroll up
                        && value - scrollOffset < 100 // it's not some mystery jump
                    /// Scroll up too much and the tracker is lost
                    let checkerOutOfScope = value <= 0
                    if checkerOutOfScope || scrollUpToThreshold {
                        isPinnedToBottom = false
                    }

                    scrollOffset = value
                    updatePinningState()
                }
                .overlay(alignment: .bottom) {
                    WithViewStore(chat, observe: \.isReceivingMessage) { viewStore in
                        StopRespondingButton(chat: chat)
                            .padding(.bottom, 8)
                            .opacity(viewStore.state ? 1 : 0)
                            .disabled(!viewStore.state)
                            .transformEffect(.init(translationX: 0, y: viewStore.state ? 0 : 20))
                            .animation(.easeInOut(duration: 0.2), value: viewStore.state)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    scrollToBottomButton(proxy: proxy)
                }
                .background {
                    PinToBottomHandler(chat: chat, pinnedToBottom: $isPinnedToBottom) {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }
        }
    }

    @MainActor
    func updatePinningState() {
        // where does the 32 come from?
        withAnimation {
            isScrollToBottomButtonDisplayed = scrollOffset > listHeight + 32 + 20
                || scrollOffset <= 0
        }
    }

    @ViewBuilder
    func scrollToBottomButton(proxy: ScrollViewProxy) -> some View {
        Button(action: {
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

    struct PinToBottomHandler: View {
        let chat: StoreOf<Chat>
        @Binding var pinnedToBottom: Bool
        let scrollToBottom: () -> Void

        @State var isInitialLoad = true

        struct PinToBottomRelatedState: Equatable {
            var isReceivingMessage: Bool
            var lastMessage: ChatMessage?
        }

        var body: some View {
            WithViewStore(chat, observe: {
                PinToBottomRelatedState(
                    isReceivingMessage: $0.isReceivingMessage,
                    lastMessage: $0.history.last
                )
            }) { viewStore in
                EmptyView()
                    .onChange(of: viewStore.state.isReceivingMessage) { isReceiving in
                        if isReceiving {
                            pinnedToBottom = true
                        }
                    }
                    .onChange(of: viewStore.state.lastMessage) { _ in
                        if pinnedToBottom || isInitialLoad {
                            if isInitialLoad {
                                isInitialLoad = false
                            }
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
        WithViewStore(chat, observe: \.history) { viewStore in
            ForEach(viewStore.state, id: \.id) { message in
                let text = message.text

                switch message.role {
                case .user:
                    UserMessage(id: message.id, text: text, chat: chat)
                        .listRowInsets(EdgeInsets(
                            top: 0,
                            leading: -8,
                            bottom: 0,
                            trailing: -8
                        ))
                        .padding(.vertical, 4)
                case .assistant:
                    BotMessage(id: message.id, text: text, chat: chat)
                        .listRowInsets(EdgeInsets(
                            top: 0,
                            leading: -8,
                            bottom: 0,
                            trailing: -8
                        ))
                        .padding(.vertical, 4)
                case .function:
                    FunctionMessage(id: message.id, text: text)
                case .ignored:
                    EmptyView()
                }
            }
        }
    }
}

private struct StopRespondingButton: View {
    let chat: StoreOf<Chat>

    var body: some View {
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
    }
}

private struct Instruction: View {
    let chat: StoreOf<Chat>

    var body: some View {
        Group {
            Markdown(
                """
                You can use plugins to perform various tasks.

                | Plugin Name | Description |
                | --- | --- |
                | `/run` | Runs a command under the project root |
                | `/math` | Solves a math problem in natural language |
                | `/search` | Searches on Bing and summarizes the results |
                | `/shortcut(name)` | Runs a shortcut from the Shortcuts.app, with the previous message as input |
                | `/shortcutInput(name)` | Runs a shortcut and uses its result as a new message |

                To use plugins, you can prefix a message with `/pluginName`.
                """
            )
            .modifier(InstructionModifier())

            Markdown(
                """
                You can use scopes to give the bot extra abilities.

                | Scope Name | Abilities |
                | --- | --- |
                | `@file` | Read the metadata of the editing file |
                | `@code` | Read the code and metadata in the editing file |
                | `@sense`| Experimental. Read the relevant code of the focused editor |
                | `@project` | Experimental. Access content of the project |
                | `@web` (beta) | Search on Bing or query from a web page |

                To use scopes, you can prefix a message with `@code`.

                You can use shorthand to represent a scope, such as `@c`, and enable multiple scopes with `@c+web`.
                """
            )
            .modifier(InstructionModifier())

            WithViewStore(chat, observe: \.chatMenu.defaultScopes) { viewStore in
                Markdown(
                    """
                    Hello, I am your AI programming assistant. I can identify issues, explain and even improve code.

                    \({
                        if viewStore.state.isEmpty {
                            return "No scope is enabled by default"
                        } else {
                            let scopes = viewStore.state.map(\.rawValue).sorted()
                                .joined(separator: ", ")
                            return "Default scopes: `\(scopes)`"
                        }
                    }())
                    """
                )
                .modifier(InstructionModifier())
            }
        }
    }

    struct InstructionModifier: ViewModifier {
        @AppStorage(\.chatFontSize) var chatFontSize

        func body(content: Content) -> some View {
            content
                .textSelection(.enabled)
                .markdownTheme(.custom(fontSize: chatFontSize))
                .opacity(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }
        }
    }
}

private struct UserMessage: View {
    let id: String
    let text: String
    let chat: StoreOf<Chat>
    @Environment(\.colorScheme) var colorScheme
    @AppStorage(\.chatFontSize) var chatFontSize
    @AppStorage(\.chatCodeFontSize) var chatCodeFontSize

    var body: some View {
        Markdown(text)
            .textSelection(.enabled)
            .markdownTheme(.custom(fontSize: chatFontSize))
            .markdownCodeSyntaxHighlighter(
                ChatCodeSyntaxHighlighter(
                    brightMode: colorScheme != .dark,
                    fontSize: chatCodeFontSize
                )
            )
            .frame(alignment: .leading)
            .padding()
            .background {
                RoundedCorners(tl: r, tr: r, bl: r, br: 0)
                    .fill(Color.userChatContentBackground)
            }
            .overlay {
                RoundedCorners(tl: r, tr: r, bl: r, br: 0)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            }
            .padding(.leading)
            .padding(.trailing, 8)
            .shadow(color: .black.opacity(0.1), radius: 2)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .contextMenu {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }

                Button("Send Again") {
                    chat.send(.resendMessageButtonTapped(id))
                }

                Button("Set as Extra System Prompt") {
                    chat.send(.setAsExtraPromptButtonTapped(id))
                }

                Divider()

                Button("Delete") {
                    chat.send(.deleteMessageButtonTapped(id))
                }
            }
    }
}

private struct BotMessage: View {
    let id: String
    let text: String
    let chat: StoreOf<Chat>
    @Environment(\.colorScheme) var colorScheme
    @AppStorage(\.chatFontSize) var chatFontSize
    @AppStorage(\.chatCodeFontSize) var chatCodeFontSize

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            Markdown(text)
                .textSelection(.enabled)
                .markdownTheme(.custom(fontSize: chatFontSize))
                .markdownCodeSyntaxHighlighter(
                    ChatCodeSyntaxHighlighter(
                        brightMode: colorScheme != .dark,
                        fontSize: chatCodeFontSize
                    )
                )
                .frame(alignment: .trailing)
                .padding()
                .background {
                    RoundedCorners(tl: r, tr: r, bl: 0, br: r)
                        .fill(Color.contentBackground)
                }
                .overlay {
                    RoundedCorners(tl: r, tr: r, bl: 0, br: r)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }
                .padding(.leading, 8)
                .shadow(color: .black.opacity(0.1), radius: 2)
                .contextMenu {
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }

                    Button("Set as Extra System Prompt") {
                        chat.send(.setAsExtraPromptButtonTapped(id))
                    }

                    Divider()

                    Button("Delete") {
                        chat.send(.deleteMessageButtonTapped(id))
                    }
                }

            CopyButton {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 2)
    }
}

struct FunctionMessage: View {
    let id: String
    let text: String
    @AppStorage(\.chatFontSize) var chatFontSize

    var body: some View {
        Markdown(text)
            .textSelection(.enabled)
            .markdownTheme(.functionCall(fontSize: chatFontSize))
            .padding(.vertical, 2)
            .padding(.trailing, 2)
    }
}

struct ChatPanelInputArea: View {
    let chat: StoreOf<Chat>
    @FocusState var isInputAreaFocused: Bool

    var body: some View {
        HStack {
            clearButton
            textEditor
        }
        .onAppear {
            isInputAreaFocused = true
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

    @MainActor
    var textEditor: some View {
        HStack(spacing: 0) {
            WithViewStore(chat, removeDuplicates: { $0.typedMessage == $1.typedMessage }) {
                viewStore in
                ZStack(alignment: .center) {
                    // a hack to support dynamic height of TextEditor
                    Text(
                        viewStore.state.typedMessage.isEmpty ? "Hi" : viewStore.state.typedMessage
                    ).opacity(0)
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity, maxHeight: 400)
                        .padding(.top, 1)
                        .padding(.bottom, 2)
                        .padding(.horizontal, 4)

                    CustomTextEditor(
                        text: viewStore.$typedMessage,
                        font: .systemFont(ofSize: 14),
                        onSubmit: { viewStore.send(.sendButtonTapped) },
                        completions: chatAutoCompletion
                    )
                    .padding(.top, 1)
                    .padding(.bottom, -1)
                }
                .focused($isInputAreaFocused)
                .padding(8)
                .fixedSize(horizontal: false, vertical: true)
            }

            WithViewStore(chat, observe: \.isReceivingMessage) { viewStore in
                Button(action: {
                    viewStore.send(.sendButtonTapped)
                }) {
                    Image(systemName: "paperplane.fill")
                        .padding(8)
                }
                .buttonStyle(.plain)
                .disabled(viewStore.state)
                .keyboardShortcut(KeyEquivalent.return, modifiers: [])
            }
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
                isInputAreaFocused = true
            }) {
                EmptyView()
            }
            .keyboardShortcut("l", modifiers: [.command])
        }
    }

    func chatAutoCompletion(text: String, proposed: [String], range: NSRange) -> [String] {
        guard text.count == 1 else { return [] }
        let plugins = [String]() // chat.pluginIdentifiers.map { "/\($0)" }
        let availableFeatures = plugins + [
            "/exit",
            "@code",
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

struct RoundedCorners: Shape {
    var tl: CGFloat = 0.0
    var tr: CGFloat = 0.0
    var bl: CGFloat = 0.0
    var br: CGFloat = 0.0

    func path(in rect: CGRect) -> Path {
        Path { path in

            let w = rect.size.width
            let h = rect.size.height

            // Make sure we do not exceed the size of the rectangle
            let tr = min(min(self.tr, h / 2), w / 2)
            let tl = min(min(self.tl, h / 2), w / 2)
            let bl = min(min(self.bl, h / 2), w / 2)
            let br = min(min(self.br, h / 2), w / 2)

            path.move(to: CGPoint(x: w / 2.0, y: 0))
            path.addLine(to: CGPoint(x: w - tr, y: 0))
            path.addArc(
                center: CGPoint(x: w - tr, y: tr),
                radius: tr,
                startAngle: Angle(degrees: -90),
                endAngle: Angle(degrees: 0),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: w, y: h - br))
            path.addArc(
                center: CGPoint(x: w - br, y: h - br),
                radius: br,
                startAngle: Angle(degrees: 0),
                endAngle: Angle(degrees: 90),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: bl, y: h))
            path.addArc(
                center: CGPoint(x: bl, y: h - bl),
                radius: bl,
                startAngle: Angle(degrees: 90),
                endAngle: Angle(degrees: 180),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: 0, y: tl))
            path.addArc(
                center: CGPoint(x: tl, y: tl),
                radius: tl,
                startAngle: Angle(degrees: 180),
                endAngle: Angle(degrees: 270),
                clockwise: false
            )
            path.closeSubpath()
        }
    }
}

struct GlobalChatSwitchToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            Text(configuration.isOn ? "Shared Conversation" : "Local Conversation")
                .foregroundStyle(.tertiary)

            RoundedRectangle(cornerRadius: 10, style: .circular)
                .foregroundColor(configuration.isOn ? Color.indigo : .gray.opacity(0.5))
                .frame(width: 30, height: 20, alignment: .center)
                .overlay(
                    Circle()
                        .fill(.regularMaterial)
                        .padding(.all, 2)
                        .overlay(
                            Image(
                                systemName: configuration
                                    .isOn ? "globe" : "doc.circle"
                            )
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12, alignment: .center)
                            .foregroundStyle(.secondary)
                        )
                        .offset(x: configuration.isOn ? 5 : -5, y: 0)
                        .animation(.linear(duration: 0.1), value: configuration.isOn)
                )
                .onTapGesture { configuration.isOn.toggle() }
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .circular)
                        .stroke(.black.opacity(0.2), lineWidth: 1)
                }
        }
    }
}

// MARK: - Previews

struct ChatPanel_Preview: PreviewProvider {
    static let history: [ChatMessage] = [
        .init(
            id: "1",
            role: .user,
            text: "**Hello**"
        ),
        .init(
            id: "2",
            role: .assistant,
            text: """
            ```swift
            func foo() {}
            ```
            **Hey**! What can I do for you?**Hey**! What can I do for you?**Hey**! What can I do for you?**Hey**! What can I do for you?
            """
        ),
        .init(id: "7", role: .ignored, text: "Ignored"),
        .init(id: "6", role: .function, text: """
        Searching for something...
        - abc
        - [def](https://1.com)
        > hello
        > hi
        """),
        .init(id: "5", role: .assistant, text: "Yooo"),
        .init(id: "4", role: .user, text: "Yeeeehh"),
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
            """#
        ),
    ]

    static var previews: some View {
        ChatPanel(chat: .init(
            initialState: .init(history: ChatPanel_Preview.history, isReceivingMessage: true),
            reducer: Chat(service: .init())
        ))
        .frame(width: 450, height: 1200)
        .colorScheme(.dark)
    }
}

struct ChatPanel_EmptyChat_Preview: PreviewProvider {
    static var previews: some View {
        ChatPanel(chat: .init(
            initialState: .init(history: [], isReceivingMessage: false),
            reducer: Chat(service: .init())
        ))
        .padding()
        .frame(width: 450, height: 600)
        .colorScheme(.dark)
    }
}

struct ChatCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    let brightMode: Bool
    let fontSize: Double

    init(brightMode: Bool, fontSize: Double) {
        self.brightMode = brightMode
        self.fontSize = fontSize
    }

    func highlightCode(_ content: String, language: String?) -> Text {
        let content = highlightedCodeBlock(
            code: content,
            language: language ?? "",
            brightMode: brightMode,
            fontSize: fontSize
        )
        return Text(AttributedString(content))
    }
}

struct ChatPanel_InputText_Preview: PreviewProvider {
    static var previews: some View {
        ChatPanel(chat: .init(
            initialState: .init(history: ChatPanel_Preview.history, isReceivingMessage: false),
            reducer: Chat(service: .init())
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
                reducer: Chat(service: .init())
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
            reducer: Chat(service: .init())
        ))
        .padding()
        .frame(width: 450, height: 600)
        .colorScheme(.light)
    }
}

