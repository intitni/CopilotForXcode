import MarkdownUI
import SwiftUI

struct ChatPanel: View {
    var viewModel: SuggestionPanelViewModel
    @ObservedObject var chat: ChatRoom
    @Namespace var inputAreaNamespace
    @State var typedMessage = ""

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack {
                ChatPanelMessages(chat: chat, inputAreaNamespace: inputAreaNamespace)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                if !chat.isReceivingMessage {
                    ChatPanelInputArea(
                        chat: chat,
                        inputAreaNamespace: inputAreaNamespace,
                        typedMessage: $typedMessage
                    )
                }
            }
            .animation(.linear(duration: 0.2), value: chat.isReceivingMessage)

            // close button
            Button(action: {
                chat.close()
            }) {
                Image(systemName: "xmark")
                    .padding(8)
                    .background(.regularMaterial, in: Circle())
                    .padding([.leading, .bottom], 8)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

struct ChatPanelMessages: View {
    @ObservedObject var chat: ChatRoom
    var inputAreaNamespace: Namespace.ID

    var body: some View {
        ScrollView {
            LazyVStack {
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
                    }
                    .buttonStyle(.plain)
                    .xcodeStyleFrame()
                    .matchedGeometryEffect(id: "input", in: inputAreaNamespace)
                }

                if chat.history.isEmpty {
                    Text("New Chat")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color.contentBackground)
                        )
                        .xcodeStyleFrame()
                        .rotationEffect(Angle(degrees: 180))
                }
                
                ForEach(chat.history.reversed(), id: \.id) { message in
                    let text = message.text.isEmpty && !message.isUser ? "..." : message
                        .text

                    Markdown(text)
                        .textSelection(.enabled)
                        .markdownTheme(.gitHub.text {
                            BackgroundColor(Color.clear)
                        })
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(
                                    message.isUser
                                        ? Color.userChatContentBackground
                                        : Color.contentBackground
                                )
                        )
                        .xcodeStyleFrame()
                        .rotationEffect(Angle(degrees: 180))
                }
            }
        }
        .rotationEffect(Angle(degrees: 180))
    }
}

struct ChatPanelInputArea: View {
    @ObservedObject var chat: ChatRoom
    var inputAreaNamespace: Namespace.ID
    @Binding var typedMessage: String

    var body: some View {
        HStack {
            // clear button
            Button(action: {
                chat.clear()
            }) {
                Image(systemName: "eraser.line.dashed.fill")
                    .padding(8)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .xcodeStyleFrame()

            Group {
                if #available(macOS 13.0, *) {
                    TextField("Type a message", text: $typedMessage, axis: .vertical)
                } else {
                    TextField("Type a message", text: $typedMessage)
                }
            }
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .textFieldStyle(.plain)
            .padding(8)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .xcodeStyleFrame()
            .onSubmit {
                if typedMessage.isEmpty { return }
                chat.send(typedMessage)
                typedMessage = ""
            }
            .matchedGeometryEffect(id: "input", in: inputAreaNamespace)

            Button(action: {
                if typedMessage.isEmpty { return }
                chat.send(typedMessage)
                typedMessage = ""
            }) {
                Image(systemName: "paperplane.fill")
                    .padding(8)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .xcodeStyleFrame()
        }
    }
}

struct ChatPanel_Preview: PreviewProvider {
    static let history: [ChatMessage] = [
        .init(
            id: "1",
            isUser: true,
            text: "**Hello**"
        ),
        .init(id: "2", isUser: false, text: "**Hey**! What can I do for you?"),
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
        .padding(8)
        .background(Color.contentBackground)
        .frame(width: 450, height: 500)
        .colorScheme(.dark)
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
        .padding(8)
        .background(Color.contentBackground)
        .frame(width: 450, height: 500)
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
            typedMessage: "Hello\nWorld"
        )
        .padding(8)
        .background(Color.contentBackground)
        .frame(width: 450, height: 500)
        .colorScheme(.dark)
    }
}

struct ChatPanel_Light_Preview: PreviewProvider {
    static var previews: some View {
        ChatPanel(viewModel: .init(
            isPanelDisplayed: true
        ), chat: .init(
            history: ChatPanel_Preview.history,
            isReceivingMessage: true
        ))
        .padding(8)
        .background(Color.contentBackground)
        .frame(width: 450, height: 500)
        .colorScheme(.light)
    }
}
