import MarkdownUI
import SwiftUI

struct ChatPanel: View {
    @ObservedObject var viewModel: SuggestionPanelViewModel
    @ObservedObject var chat: ChatRoom
    @Namespace var inputAreaNamespace
    @State var typedMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            ChatPanelToolbar(chat: chat)
            Divider()
            ChatPanelMessages(
                chat: chat,
                inputAreaNamespace: inputAreaNamespace,
                colorScheme: viewModel.colorScheme
            )
            Divider()
            ChatPanelInputArea(
                chat: chat,
                inputAreaNamespace: inputAreaNamespace,
                typedMessage: $typedMessage
            )
        }
        .animation(.linear(duration: 0.2), value: chat.isReceivingMessage)
        .background(.regularMaterial)
        .xcodeStyleFrame()
    }
}

struct ChatPanelToolbar: View {
    let chat: ChatRoom

    var body: some View {
        HStack {
            Spacer()

            Button(action: {
                chat.close()
            }) {
                Image(systemName: "xmark")
                    .padding(4)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(.regularMaterial)
    }
}

struct ChatPanelMessages: View {
    @ObservedObject var chat: ChatRoom
    var inputAreaNamespace: Namespace.ID
    var colorScheme: ColorScheme
    @AppStorage(\.disableLazyVStack) var disableLazyVStack

    @ViewBuilder
    func vstack(@ViewBuilder content: () -> some View) -> some View {
        if disableLazyVStack {
            VStack(spacing: 4) {
                content()
            }
        } else {
            LazyVStack(spacing: 4) {
                content()
            }
        }
    }

    var body: some View {
        ScrollView {
            vstack {
                Spacer()

                if chat.isReceivingMessage {
                    Button(action: {
                        chat.stop()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                            Text("Stop Responding")
                        }
                        .rotationEffect(Angle(degrees: 180))
                        .padding(8)
                        .background(
                            .regularMaterial,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(x: -1, y: 1, anchor: .center)
                }

                if chat.history.isEmpty {
                    Text("New Chat")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .rotationEffect(Angle(degrees: 180))
                        .scaleEffect(x: -1, y: 1, anchor: .center)
                        .foregroundStyle(.secondary)
                }

                ForEach(chat.history.reversed(), id: \.id) { message in
                    let text = message.text.isEmpty && !message.isUser ? "..." : message
                        .text

                    if message.isUser {
                        Markdown(text)
                            .textSelection(.enabled)
                            .markdownTheme(.gitHub.text {
                                BackgroundColor(Color.clear)
                            })
                            .markdownCodeSyntaxHighlighter(
                                ChatCodeSyntaxHighlighter(brightMode: colorScheme != .dark)
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background {
                                RoundedCorners(tl: 12, tr: 12, bl: 12)
                                    .fill(Color.userChatContentBackground)
                            }
                            .overlay {
                                RoundedCorners(tl: 12, tr: 12, bl: 12)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                            }
                            .padding(.leading)
                            .padding(.trailing, 4)
                            .rotationEffect(Angle(degrees: 180))
                            .scaleEffect(x: -1, y: 1, anchor: .center)
                    } else {
                        Markdown(text)
                            .textSelection(.enabled)
                            .markdownTheme(.gitHub.text {
                                BackgroundColor(Color.clear)
                            })
                            .markdownCodeSyntaxHighlighter(
                                ChatCodeSyntaxHighlighter(brightMode: colorScheme != .dark)
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background {
                                RoundedCorners(tl: 12, tr: 12, br: 12)
                                    .fill(Color.contentBackground)
                            }
                            .overlay {
                                RoundedCorners(tl: 12, tr: 12, br: 12)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                            }
                            .padding(.leading, 4)
                            .padding(.trailing)
                            .rotationEffect(Angle(degrees: 180))
                            .scaleEffect(x: -1, y: 1, anchor: .center)
                    }
                }

                Spacer()
            }
        }
        .rotationEffect(Angle(degrees: 180))
        .scaleEffect(x: -1, y: 1, anchor: .center)
    }
}

struct ChatPanelInputArea: View {
    @ObservedObject var chat: ChatRoom
    var inputAreaNamespace: Namespace.ID
    @Binding var typedMessage: String
    @FocusState var isInputAreaFocused: Bool

    var body: some View {
        HStack {
            // clear button
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

            HStack(spacing: 0) {
                Group {
                    if #available(macOS 13.0, *) {
                        TextField("Type a message", text: $typedMessage, axis: .vertical)
                    } else {
                        TextEditor(text: $typedMessage)
                            .frame(height: 42, alignment: .leading)
                            .font(.body)
                            .background(Color.clear)
                    }
                }
                .focused($isInputAreaFocused)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .textFieldStyle(.plain)
                .padding(8)
                .onSubmit {
                    if typedMessage.isEmpty { return }
                    chat.send(typedMessage)
                    typedMessage = ""
                }

                Button(action: {
                    if typedMessage.isEmpty { return }
                    chat.send(typedMessage)
                    typedMessage = ""
                }) {
                    Image(systemName: "paperplane.fill")
                        .padding(8)
                }
                .buttonStyle(.plain)
                .disabled(chat.isReceivingMessage)
            }
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .controlColor), lineWidth: 1)
            }
        }
        .onAppear {
            isInputAreaFocused = true
        }
        .padding(8)
        .background(.ultraThickMaterial)
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

// MARK: - Previews

struct ChatPanel_Preview: PreviewProvider {
    static let history: [ChatMessage] = [
        .init(
            id: "1",
            isUser: true,
            text: "**Hello**"
        ),
        .init(id: "2", isUser: false, text: "**Hey**! What can I do for you?"),
        .init(id: "5", isUser: false, text: "Yooo"),
        .init(id: "4", isUser: true, text: "Yeeeehh"),
        .init(
            id: "3",
            isUser: true,
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
        ChatPanel(viewModel: .init(
            isPanelDisplayed: true
        ), chat: .init(
            history: ChatPanel_Preview.history,
            isReceivingMessage: true
        ))
        .frame(width: 450, height: 500)
        .colorScheme(.dark)
    }
}

struct ChatPanel_EmptyChat_Preview: PreviewProvider {
    static var previews: some View {
        ChatPanel(viewModel: .init(
            isPanelDisplayed: true
        ), chat: .init(
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

    init(brightMode: Bool) {
        self.brightMode = brightMode
    }

    func highlightCode(_ content: String, language: String?) -> Text {
        let content = highlightedCodeBlock(
            code: content,
            language: language ?? "",
            brightMode: brightMode
        )
        return Text(AttributedString(content))
    }
}

struct ChatPanel_InputText_Preview: PreviewProvider {
    static var previews: some View {
        ChatPanel(viewModel: .init(
            isPanelDisplayed: true
        ), chat: .init(
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
            viewModel: .init(
                isPanelDisplayed: true
            ),
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
        ChatPanel(viewModel: .init(
            isPanelDisplayed: true,
            colorScheme: .light
        ), chat: .init(
            history: ChatPanel_Preview.history,
            isReceivingMessage: true
        ))
        .padding()
        .frame(width: 450, height: 600)
        .colorScheme(.light)
    }
}
