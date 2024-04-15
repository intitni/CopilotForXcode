import ComposableArchitecture
import Foundation
import MarkdownUI
import SwiftUI

struct UserMessage: View {
    var r: Double { messageBubbleCornerRadius }
    let id: String
    let text: String
    let chat: StoreOf<Chat>
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ThemedMarkdownText(text)
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
            .shadow(color: .black.opacity(0.05), radius: 6)
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

#Preview {
    UserMessage(
        id: "A",
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
        chat: .init(
            initialState: .init(history: [], isReceivingMessage: false),
            reducer: Chat(service: .init())
        )
    )
    .padding()
    .fixedSize(horizontal: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
}

