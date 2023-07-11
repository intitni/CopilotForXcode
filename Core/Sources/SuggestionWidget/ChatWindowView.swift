import ActiveApplicationMonitor
import AppKit
import ChatGPTChatTab
import ChatTab
import ComposableArchitecture
import SwiftUI

private let r: Double = 8

struct ChatWindowView: View {
    let store: StoreOf<ChatPanelFeature>

    struct OverallState: Equatable {
        var isPanelDisplayed: Bool
        var colorScheme: ColorScheme
        var selectedTabId: String?
    }

    var body: some View {
        WithViewStore(
            store,
            observe: {
                OverallState(
                    isPanelDisplayed: $0.isPanelDisplayed,
                    colorScheme: $0.colorScheme,
                    selectedTabId: $0.chatTapGroup.selectedTabId
                )
            }
        ) { viewStore in
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.tertiary)
                    .frame(width: 120, height: 4)
                    .frame(height: 16)

                Divider()

                ChatTabBar(store: store)
                    .frame(height: 26)

                Divider()

                ChatTabContainer(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background {
                Button(action: {
                    viewStore.send(.hideButtonClicked)
                }) {
                    EmptyView()
                }
                .opacity(0)
                .keyboardShortcut("M", modifiers: [.command])

                Button(action: {
                    viewStore.send(.closeActiveTabClicked)
                }) {
                    EmptyView()
                }
                .opacity(0)
                .keyboardShortcut("W", modifiers: [.command])
            }
            .background(.regularMaterial)
            .xcodeStyleFrame()
            .opacity(viewStore.state.isPanelDisplayed ? 1 : 0)
            .frame(minWidth: Style.panelWidth, minHeight: Style.panelHeight)
            .preferredColorScheme(viewStore.state.colorScheme)
        }
    }
}

struct ChatTabBar: View {
    let store: StoreOf<ChatPanelFeature>

    struct TabBarState: Equatable {
        var tabInfo: [ChatTabInfo]
        var selectedTabId: String
    }

    var body: some View {
        WithViewStore(
            store,
            observe: { TabBarState(
                tabInfo: $0.chatTapGroup.tabInfo,
                selectedTabId: $0.chatTapGroup.selectedTabId
                    ?? $0.chatTapGroup.tabInfo.first?.id ?? ""
            ) }
        ) { viewStore in
            HStack(spacing: 0) {
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        ForEach(viewStore.state.tabInfo, id: \.id) { info in
                            ChatTabBarButton(
                                store: store,
                                info: info,
                                isSelected: info.id == viewStore.state.selectedTabId
                            )
                        }
                    }
                }

                Divider()

                Button(action: {
                    store.send(.createNewTapButtonClicked(type: ""))
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.secondary)
                        .padding(8)
                }.buttonStyle(.plain)
            }
        }
    }
}

struct ChatTabBarButton: View {
    let store: StoreOf<ChatPanelFeature>
    let info: ChatTabInfo
    let isSelected: Bool
    @State var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            Button(action: {
                store.send(.tabClicked(id: info.id))
            }) {
                Text(info.title)
                    .font(.callout)
                    .lineLimit(1)
                    .frame(maxWidth: 120)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 32)

            .overlay(alignment: .leading) {
                Button(action: {
                    store.send(.closeTabButtonClicked(id: info.id))
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(2)
                .padding(.leading, 8)
                .opacity(isHovered ? 1 : 0)
            }
            .onHover { isHovered = $0 }
            .animation(.linear(duration: 0.1), value: isHovered)
            .animation(.linear(duration: 0.1), value: isSelected)

            Divider().padding(.vertical, 6)
        }
        .background(isSelected ? Color(nsColor: .selectedControlColor) : Color.clear)
        .frame(maxHeight: .infinity)
    }
}

struct ChatTabContainer: View {
    let store: StoreOf<ChatPanelFeature>

    struct TabContainerState: Equatable {
        var tabs: [BaseChatTab]
        var selectedTabId: String?
    }

    var body: some View {
        WithViewStore(
            store,
            observe: {
                TabContainerState(
                    tabs: $0.chatTapGroup.tabs,
                    selectedTabId: $0.chatTapGroup.selectedTabId
                        ?? $0.chatTapGroup.tabInfo.first?.id ?? ""
                )
            }
        ) { viewStore in
            ZStack {
                if viewStore.state.tabs.isEmpty {
                    Text("Empty")
                } else {
                    ForEach(viewStore.state.tabs, id: \.id) { tab in
                        tab.body
                            .opacity(tab.id == viewStore.state.selectedTabId ? 1 : 0)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .onPreferenceChange(ChatTabInfoPreferenceKey.self) { items in
            store.send(.updateChatTabInfo(items))
        }
    }
}

struct ChatWindowView_Previews: PreviewProvider {
    class FakeChatTab: ChatTab {
        func buildView() -> any View {
            ChatPanel(
                chat: .init(
                    history: [
                        .init(id: "1", role: .assistant, text: "Hello World"),
                    ],
                    isReceivingMessage: false
                ),
                typedMessage: "Hello World!"
            )
        }

        override init(id: String, title: String) {
            super.init(id: id, title: title)
        }
    }

    static var previews: some View {
        ChatWindowView(
            store: .init(
                initialState: .init(
                    chatTapGroup: .init(
                        tabs: [
                            FakeChatTab(id: "1", title: "Hello I am a chatbot"),
                            EmptyChatTab(id: "2"),
                        ],
                        selectedTabId: "1"
                    ),
                    isPanelDisplayed: true
                ),
                reducer: ChatPanelFeature()
            )
        )
        .padding()
    }
}

