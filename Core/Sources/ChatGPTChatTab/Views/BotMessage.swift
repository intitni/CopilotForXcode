import ComposableArchitecture
import Foundation
import MarkdownUI
import SharedUIComponents
import SwiftUI

struct BotMessage: View {
    var r: Double { messageBubbleCornerRadius }
    let id: String
    let text: String
    let markdownContent: MarkdownContent
    let references: [DisplayedChatMessage.Reference]
    let chat: StoreOf<Chat>
    @Environment(\.colorScheme) var colorScheme

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
                        ReferenceList(references: references, chat: chat)
                    }
                }

                ThemedMarkdownText(markdownContent)
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
            .shadow(color: .black.opacity(0.05), radius: 6)
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
    let chat: StoreOf<Chat>

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(0..<references.endIndex, id: \.self) { index in
                        WithPerceptionTracking {
                            let reference = references[index]

                            Button(action: {
                                chat.send(.referenceClicked(reference))
                            }) {
                                HStack(spacing: 8) {
                                    ReferenceIcon(kind: reference.kind)
                                        .layoutPriority(2)
                                    Text(reference.title)
                                        .truncationMode(.middle)
                                        .lineLimit(1)
                                        .layoutPriority(1)
                                    Text(reference.subtitle)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .foregroundStyle(.tertiary)
                                        .layoutPriority(0)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .frame(maxWidth: 500, maxHeight: 500)
        }
    }
}

struct ReferenceIcon: View {
    let kind: DisplayedChatMessage.Reference.Kind

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill({
                switch kind {
                case .symbol(let symbol, _, _, _):
                    switch symbol {
                    case .class:
                        Color.purple
                    case .struct:
                        Color.purple
                    case .enum:
                        Color.purple
                    case .actor:
                        Color.purple
                    case .protocol:
                        Color.purple
                    case .extension:
                        Color.indigo
                    case .case:
                        Color.green
                    case .property:
                        Color.teal
                    case .typealias:
                        Color.orange
                    case .function:
                        Color.teal
                    case .method:
                        Color.blue
                    }
                case .text:
                    Color.gray
                case .webpage:
                    Color.blue
                case .textFile:
                    Color.gray
                case .other:
                    Color.gray
                }
            }())
            .frame(width: 22, height: 22)
            .overlay(alignment: .center) {
                Group {
                    switch kind {
                    case .symbol(let symbol, _, _, _):
                        switch symbol {
                        case .class:
                            Text("C")
                        case .struct:
                            Text("S")
                        case .enum:
                            Text("E")
                        case .actor:
                            Text("A")
                        case .protocol:
                            Text("Pr")
                        case .extension:
                            Text("Ex")
                        case .case:
                            Text("K")
                        case .property:
                            Text("P")
                        case .typealias:
                            Text("T")
                        case .function:
                            Text("𝑓")
                        case .method:
                            Text("M")
                        }
                    case .text:
                        Text("Tx")
                    case .webpage:
                        Text("Wb")
                    case .other:
                        Text("Ot")
                    case .textFile:
                        Text("Tx")
                    }
                }
                .font(.system(size: 12).monospaced())
                .foregroundColor(.white)
            }
    }
}

#Preview("Bot Message") {
    let text = """
        **Hey**! What can I do for you?**Hey**! What can I do for you?**Hey**! What can I do for you?**Hey**! What can I do for you?
        ```swift
        func foo() {}
        ```
        """
    return BotMessage(
        id: "1",
        text: text,
        markdownContent: .init(text),
        references: .init(repeating: .init(
            title: "ReferenceList",
            subtitle: "/Core/Sources/ChatGPTChatTab/Views/BotMessage.swift:100",
            uri: "https://google.com",
            startLine: nil,
            kind: .symbol(.class, uri: "https://google.com", startLine: nil, endLine: nil)
        ), count: 20),
        chat: .init(initialState: .init(), reducer: { Chat(service: .init()) })
    )
    .padding()
    .fixedSize(horizontal: true, vertical: true)
}

#Preview("Reference List") {
    ReferenceList(references: [
        .init(
            title: "ReferenceList",
            subtitle: "/Core/Sources/ChatGPTChatTab/Views/BotMessage.swift:100",
            uri: "https://google.com",
            startLine: nil,
            kind: .symbol(.class, uri: "https://google.com", startLine: nil, endLine: nil)
        ),
        .init(
            title: "BotMessage.swift:100-102",
            subtitle: "/Core/Sources/ChatGPTChatTab/Views",
            uri: "https://google.com",
            startLine: nil,
            kind: .symbol(.struct, uri: "https://google.com", startLine: nil, endLine: nil)
        ),
        .init(
            title: "ReferenceList",
            subtitle: "/Core/Sources/ChatGPTChatTab/Views/BotMessage.swift:100",
            uri: "https://google.com",
            startLine: nil,
            kind: .symbol(.function, uri: "https://google.com", startLine: nil, endLine: nil)
        ),
        .init(
            title: "ReferenceList",
            subtitle: "/Core/Sources/ChatGPTChatTab/Views/BotMessage.swift:100",
            uri: "https://google.com",
            startLine: nil,
            kind: .symbol(.case, uri: "https://google.com", startLine: nil, endLine: nil)
        ),
        .init(
            title: "ReferenceList",
            subtitle: "/Core/Sources/ChatGPTChatTab/Views/BotMessage.swift:100",
            uri: "https://google.com",
            startLine: nil,
            kind: .symbol(.extension, uri: "https://google.com", startLine: nil, endLine: nil)
        ),
        .init(
            title: "ReferenceList",
            subtitle: "/Core/Sources/ChatGPTChatTab/Views/BotMessage.swift:100",
            uri: "https://google.com",
            startLine: nil,
            kind: .webpage(uri: "https://google.com")
        ),
    ], chat: .init(initialState: .init(), reducer: { Chat(service: .init()) }))
}
