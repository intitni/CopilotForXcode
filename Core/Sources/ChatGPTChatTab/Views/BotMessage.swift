import ComposableArchitecture
import Foundation
import MarkdownUI
import SharedUIComponents
import SwiftUI

struct BotMessage: View {
    var r: Double { messageBubbleCornerRadius }
    let id: String
    let text: String
    let references: [DisplayedChatMessage.Reference]
    let chat: StoreOf<Chat>
    @Environment(\.colorScheme) var colorScheme
    @AppStorage(\.chatFontSize) var chatFontSize
    @AppStorage(\.chatCodeFontSize) var chatCodeFontSize

    @State var isReferencesPresented = false
    @State var isReferencesHovered = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            VStack(alignment: .leading, spacing: 16) {
                if !references.isEmpty {
                    Button(action: {
                        isReferencesPresented.toggle()
                    }, label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                            Text("Used \(references.count) references")
                        }
                        .padding(8)
                        .background {
                            RoundedRectangle(cornerRadius: r - 4)
                                .foregroundStyle(Color(isReferencesHovered ? .black : .clear))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: r - 4)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        }
                        .foregroundStyle(.secondary)
                    })
                    .buttonStyle(.plain)
                    .popover(isPresented: $isReferencesPresented, arrowEdge: .trailing) {
                        ReferenceList(references: references)
                    }
                }

                Markdown(text)
                    .textSelection(.enabled)
                    .markdownTheme(.custom(fontSize: chatFontSize))
                    .markdownCodeSyntaxHighlighter(
                        ChatCodeSyntaxHighlighter(
                            brightMode: colorScheme != .dark,
                            fontSize: chatCodeFontSize
                        )
                    )
            }
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

struct ReferenceList: View {
    let references: [DisplayedChatMessage.Reference]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<references.endIndex, id: \.self) { index in
                    let reference = references[index]
                    
                    Button(action: {
                        print("")
                    }) {
                        HStack(spacing: 8) {
                            Text(reference.title)
                            Text(reference.subtitle)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .frame(maxHeight: 500)
        }
    }
}

#Preview("Bot Message") {
    BotMessage(
        id: "1",
        text: """
        **Hey**! What can I do for you?**Hey**! What can I do for you?**Hey**! What can I do for you?**Hey**! What can I do for you?
        ```swift
        func foo() {}
        ```
        """,
        references: [
            .init(
                title: "ReferenceList",
                subtitle: "/Core/Sources/ChatGPTChatTab/Views/BotMessage.swift:100",
                uri: "https://google.com"
            ),
            .init(
                title: "BotMessage.swift:100-102",
                subtitle: "/Core/Sources/ChatGPTChatTab/Views",
                uri: "https://google.com"
            ),
        ],
        chat: .init(initialState: .init(), reducer: Chat(service: .init()))
    )
    .padding()
    .fixedSize(horizontal: true, vertical: true)
}

#Preview("Reference List") {
    ReferenceList(references: [
        .init(
            title: "ReferenceList",
            subtitle: "/Core/Sources/ChatGPTChatTab/Views/BotMessage.swift:100",
            uri: "https://google.com"
        ),
        .init(
            title: "BotMessage.swift:100-102",
            subtitle: "/Core/Sources/ChatGPTChatTab/Views",
            uri: "https://google.com"
        ),
        .init(
            title: "ReferenceList",
            subtitle: "/Core/Sources/ChatGPTChatTab/Views/BotMessage.swift:100",
            uri: "https://google.com"
        ),
        .init(
            title: "ReferenceList",
            subtitle: "/Core/Sources/ChatGPTChatTab/Views/BotMessage.swift:100",
            uri: "https://google.com"
        ),
        .init(
            title: "ReferenceList",
            subtitle: "/Core/Sources/ChatGPTChatTab/Views/BotMessage.swift:100",
            uri: "https://google.com"
        ),
        .init(
            title: "ReferenceList",
            subtitle: "/Core/Sources/ChatGPTChatTab/Views/BotMessage.swift:100",
            uri: "https://google.com"
        ),
    ])
}

