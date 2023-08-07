import AppKit
import MarkdownUI
import SharedUIComponents
import SwiftUI

private let r: Double = 8

public struct ChatPanel: View {
    @ObservedObject var chat: ChatProvider
    @Namespace var inputAreaNamespace
    @State var typedMessage = ""

    public init(chat: ChatProvider, typedMessage: String = "") {
        self.chat = chat
        self.typedMessage = typedMessage
    }

    public var body: some View {
        VStack(spacing: 0) {
            ChatPanelMessages(
                chat: chat
            )
            Divider()
            ChatPanelInputArea(
                chat: chat,
                typedMessage: $typedMessage
            )
        }
        .background(.regularMaterial)
    }
}

struct ChatPanelMessages: View {
    @ObservedObject var chat: ChatProvider

    var body: some View {
        List {
            Group {
                Spacer()

                if chat.isReceivingMessage {
                    StopRespondingButton(chat: chat)
                        .padding(.vertical, 4)
                        .listRowInsets(EdgeInsets(top: 0, leading: -8, bottom: 0, trailing: -8))
                }

                ForEach(chat.history.reversed(), id: \.id) { message in
                    let text = message.text

                    switch message.role {
                    case .user:
                        UserMessage(id: message.id, text: text, chat: chat)
                            .listRowInsets(EdgeInsets(top: 0, leading: -8, bottom: 0, trailing: -8))
                            .padding(.vertical, 4)
                    case .assistant:
                        BotMessage(id: message.id, text: text, chat: chat)
                            .listRowInsets(EdgeInsets(top: 0, leading: -8, bottom: 0, trailing: -8))
                            .padding(.vertical, 4)
                    case .function:
                        FunctionMessage(id: message.id, text: text)
                    case .ignored:
                        EmptyView()
                    }
                }
                .listItemTint(.clear)

                Instruction()

                Spacer()
            }
            .scaleEffect(x: -1, y: 1, anchor: .center)
        }
        .id("\(chat.history.count), \(chat.isReceivingMessage)")
        .listStyle(.plain)
        .scaleEffect(x: 1, y: -1, anchor: .center)
    }
}

private struct StopRespondingButton: View {
    let chat: ChatProvider

    var body: some View {
        Button(action: {
            chat.stop()
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
        .scaleEffect(x: -1, y: -1, anchor: .center)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct Instruction: View {
    @AppStorage(\.useSelectionScopeByDefaultInChatContext)
    var useCodeScopeByDefaultInChatContext

    var body: some View {
        Group {
            Markdown(
                """
                Hello, I am your AI programming assistant. I can identify issues, explain and even improve code.
                                
                \(
                    useCodeScopeByDefaultInChatContext
                        ? "Scope **`@code`** is enabled by default."
                        : "Scope **`@file`** is enabled by default."
                )
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
                | `@web` (beta) | Search on Bing or query from a web page |

                To use scopes, you can prefix a message with `@code`.

                You can use shorthand to represent a scope, such as `@c`, and enable multiple scopes with `@c+web`.
                """
            )
            .modifier(InstructionModifier())

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
                .scaleEffect(x: -1, y: -1, anchor: .center)
        }
    }
}

private struct UserMessage: View {
    let id: String
    let text: String
    let chat: ChatProvider
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
            .scaleEffect(x: -1, y: -1, anchor: .center)
            .shadow(color: .black.opacity(0.1), radius: 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contextMenu {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }

                Button("Send Again") {
                    chat.resendMessage(id: id)
                }

                Button("Set as Extra System Prompt") {
                    chat.setAsExtraPrompt(id: id)
                }

                Divider()

                Button("Delete") {
                    chat.deleteMessage(id: id)
                }
            }
    }
}

private struct BotMessage: View {
    let id: String
    let text: String
    let chat: ChatProvider
    @Environment(\.colorScheme) var colorScheme
    @AppStorage(\.chatFontSize) var chatFontSize
    @AppStorage(\.chatCodeFontSize) var chatCodeFontSize

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            CopyButton {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
            .scaleEffect(x: -1, y: -1, anchor: .center)

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
                .scaleEffect(x: -1, y: -1, anchor: .center)
                .shadow(color: .black.opacity(0.1), radius: 2)
                .contextMenu {
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }

                    Button("Set as Extra System Prompt") {
                        chat.setAsExtraPrompt(id: id)
                    }

                    Divider()

                    Button("Delete") {
                        chat.deleteMessage(id: id)
                    }
                }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
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
            .scaleEffect(x: -1, y: -1, anchor: .center)
            .padding(.vertical, 2)
            .padding(.trailing, 2)
    }
}

struct ChatPanelInputArea: View {
    @ObservedObject var chat: ChatProvider
    @Binding var typedMessage: String
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

    var clearButton: some View {
        Button(action: {
            chat.clear()
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
                Circle()
                    .stroke(Color(nsColor: .controlColor), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    var textEditor: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .center) {
                // a hack to support dynamic height of TextEditor
                Text(typedMessage.isEmpty ? "Hi" : typedMessage).opacity(0)
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, maxHeight: 400)
                    .padding(.top, 1)
                    .padding(.bottom, 2)
                    .padding(.horizontal, 4)

                CustomTextEditor(
                    text: $typedMessage,
                    font: .systemFont(ofSize: 14),
                    onSubmit: { submitText() },
                    completions: chatAutoCompletion
                )
                .padding(.top, 1)
                .padding(.bottom, -1)
            }
            .focused($isInputAreaFocused)
            .padding(8)
            .fixedSize(horizontal: false, vertical: true)

            Button(action: {
                submitText()
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
                typedMessage += "\n"
            }) {
                EmptyView()
            }
            .keyboardShortcut(KeyEquivalent.return, modifiers: [.shift])
        }
    }

    func submitText() {
        if typedMessage.isEmpty { return }
        chat.send(typedMessage)
        typedMessage = ""
    }

    func chatAutoCompletion(text: String, proposed: [String], range: NSRange) -> [String] {
        guard text.count == 1 else { return [] }
        let plugins = chat.pluginIdentifiers.map { "/\($0)" }
        let availableFeatures = plugins + [
            "/exit",
            "@selection",
            "@file",
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
            history: ChatPanel_Preview.history,
            isReceivingMessage: true
        ))
        .frame(width: 450, height: 1200)
        .colorScheme(.dark)
    }
}

struct ChatPanel_EmptyChat_Preview: PreviewProvider {
    static var previews: some View {
        ChatPanel(chat: .init(
            history: [],
            isReceivingMessage: false
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
            history: ChatPanel_Preview.history,
            isReceivingMessage: false
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
                history: ChatPanel_Preview.history,
                isReceivingMessage: false
            ),
            typedMessage: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Fusce turpis dolor, malesuada quis fringilla sit amet, placerat at nunc. Suspendisse orci tortor, tempor nec blandit a, malesuada vel tellus. Nunc sed leo ligula. Ut at ligula eget turpis pharetra tristique. Integer luctus leo non elit rhoncus fermentum."
        )
        .padding()
        .frame(width: 450, height: 600)
        .colorScheme(.dark)
    }
}

struct ChatPanel_Light_Preview: PreviewProvider {
    static var previews: some View {
        ChatPanel(chat: .init(
            history: ChatPanel_Preview.history,
            isReceivingMessage: true
        ))
        .padding()
        .frame(width: 450, height: 600)
        .colorScheme(.light)
    }
}

