import MarkdownUI
import SwiftUI

struct ChatPanel: View {
    @ObservedObject var viewModel: SuggestionPanelViewModel
    @ObservedObject var chat: ChatRoom

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                LazyVStack {
                    ForEach(chat.history.reversed(), id: \.id) { message in
                        Markdown(message.text)
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
                            .rotationEffect(Angle(degrees: 180))
                    }
                }
            }
            .rotationEffect(Angle(degrees: 180))

            // close button
            Button(action: {
                viewModel.isPanelDisplayed = false
                viewModel.content = .empty
                chat.stop()
            }) {
                Image(systemName: "xmark")
                    .padding([.leading, .bottom], 16)
                    .padding([.top, .trailing], 8)
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .colorScheme(viewModel.colorScheme)
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
            isReceivingMessage: false
        ))
        .frame(width: 450, height: 500)
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
            isReceivingMessage: false
        ))
        .frame(width: 450, height: 500)
    }
}
