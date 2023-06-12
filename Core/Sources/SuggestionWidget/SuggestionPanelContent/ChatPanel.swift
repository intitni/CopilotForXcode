import MarkdownUI
import SwiftUI

struct ChatPanel: View {
    let chat: ChatProvider
    @Namespace var inputAreaNamespace
    @State var typedMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            ChatPanelToolbar(chat: chat)
            Divider()
            ChatPanelMessages(
                chat: chat,
                inputAreaNamespace: inputAreaNamespace
            )
            Divider()
            ChatPanelInputArea(
                chat: chat,
                inputAreaNamespace: inputAreaNamespace,
                typedMessage: $typedMessage
            )
        }
        .background(.regularMaterial)
        .xcodeStyleFrame()
    }
}

struct ChatPanelToolbar: View {
    @ObservedObject var chat: ChatProvider
    @AppStorage(\.useGlobalChat) var useGlobalChat

    var body: some View {
        HStack {
            Toggle(isOn: .init(get: {
                useGlobalChat
            }, set: { _ in
                chat.switchContext()
            })) { EmptyView() }
                .toggleStyle(GlobalChatSwitchToggleStyle())

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
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .background(.regularMaterial)
    }
}

struct UserMessageView: View {
    var message: ChatMessage
    @Environment(\.colorScheme) var colorScheme
    var r = 6 as Double

    var body: some View {
        let text = message.text.isEmpty ? "..." : message.text
        Markdown(text)
            .textSelection(.enabled)
            .markdownTheme(.gitHub.text {
                BackgroundColor(Color.clear)
            })
            .markdownCodeSyntaxHighlighter(
                ChatCodeSyntaxHighlighter(brightMode: colorScheme != .dark)
            )
            .frame(alignment: .trailing)
            .padding()
            .background {
                RoundedCorners(tl: r, bl: r, br: r * 1.5)
                    .fill(Color.userChatContentBackground)
            }
            .overlay {
                RoundedCorners(tl: r, bl: r, br: r * 1.5)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            }
            .padding(.leading)
            .padding(.trailing, 8)
            .rotationEffect(Angle(degrees: 180))
            .scaleEffect(x: -1, y: 1, anchor: .center)
            .shadow(color: .black.opacity(0.1), radius: 2)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

struct NonUserMessageView: View {
    var message: ChatMessage
    @Environment(\.colorScheme) var colorScheme
    var r = 6 as Double

    var body: some View {
        let text = message.text.isEmpty ? "..." : message.text
        Markdown(text)
            .textSelection(.enabled)
            .markdownTheme(.gitHub.text {
                BackgroundColor(Color.clear)
            })
            .markdownCodeSyntaxHighlighter(
                ChatCodeSyntaxHighlighter(brightMode: colorScheme != .dark)
            )
            .frame(alignment: .leading)
            .padding()
            .background {
                RoundedCorners(tr: r, bl: r * 1.5, br: r)
                    .fill(Color.contentBackground)
            }
            .overlay {
                RoundedCorners(tr: r, bl: r * 1.5, br: r)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            }
            .padding(.leading, 8)
            .padding(.trailing)
            .rotationEffect(Angle(degrees: 180))
            .scaleEffect(x: -1, y: 1, anchor: .center)
            .shadow(color: .black.opacity(0.1), radius: 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ChatPanelMessages: View {
    @ObservedObject var chat: ChatProvider
    var inputAreaNamespace: Namespace.ID
    @Environment(\.colorScheme) var colorScheme
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
                let r = 6 as Double

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
                            in: RoundedRectangle(cornerRadius: r, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: r, style: .continuous)
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
                    if message.isUser {
                        UserMessageView(message: message)
                    } else {
                        NonUserMessageView(message: message)
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
    @ObservedObject var chat: ChatProvider
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
                    if chat.isReceivingMessage { return }
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
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
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

struct GlobalChatSwitchToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
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
            
            Text(configuration.isOn ? "Global Chat" : "File Chat")
                .foregroundStyle(.tertiary)
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
        ChatPanel(chat: .init(
            history: ChatPanel_Preview.history,
            isReceivingMessage: true
        ))
        .frame(width: 450, height: 500)
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

    init(brightMode: Bool) {
        self.brightMode = brightMode
    }

    func highlightCode(_ content: String, language: String?) -> Text {
        let content = highlightedCodeBlock(
            code: content,
            language: language ?? "",
            brightMode: brightMode,
            fontSize: 12
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
