import MarkdownUI
import SwiftUI

struct ChatPanel: View {
    var viewModel: SuggestionPanelViewModel
    @ObservedObject var chat: ChatRoom
    @State var typedMessage = ""
    @Namespace var inputAreaNamespace

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack {
                ScrollView {
                    LazyVStack() {
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
                        
                        ForEach(chat.history.reversed(), id: \.id) { message in
                            let text = message.text.isEmpty && !message.isUser ? "..." : message.text
                            
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
                
                if !chat.isReceivingMessage {
                    HStack {
                        TextField("Type a message", text: $typedMessage)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(
                                .regularMaterial,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .xcodeStyleFrame()
                        
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
                    .matchedGeometryEffect(id: "input", in: inputAreaNamespace)
                }
            }

            // close button
            Button(action: {
                viewModel.isPanelDisplayed = false
                viewModel.content = .empty
                chat.stop()
            }) {
                Image(systemName: "xmark")
                    .padding([.leading, .bottom], 16)
                    .padding([.top, .trailing], 8)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

struct ChatPanel_Preview: PreviewProvider {
    static var previews: some View {
        ChatPanel(viewModel: .init(
            content: .empty,
            isPanelDisplayed: true
        ), chat: .init(
            history: [
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
            ],
            isReceivingMessage: true
        ))
        .padding(8)
        .background(Color.contentBackground)
        .frame(width: 450, height: 500)
        .colorScheme(.dark)
    }
}

struct ChatPanel_Light_Preview: PreviewProvider {
    static var previews: some View {
        ChatPanel(viewModel: .init(
            content: .empty,
            isPanelDisplayed: true,
            colorScheme: .light
        ), chat: .init(
            history: [
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
            ],
            isReceivingMessage: true
        ))
        .padding(8)
        .background(Color.contentBackground)
        .frame(width: 450, height: 500)
        .colorScheme(.light)
    }
}
