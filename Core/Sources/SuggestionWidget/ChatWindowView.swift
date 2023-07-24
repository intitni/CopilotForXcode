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

private extension View {
    func hideScrollIndicator() -> some View {
        if #available(macOS 13.0, *) {
            return scrollIndicators(.hidden)
        } else {
            return self
        }
    }
}

struct ChatTabBar: View {
    let store: StoreOf<ChatPanelFeature>

    struct TabBarState: Equatable {
        var tabs: [BaseChatTab]
        var tabInfo: [ChatTabInfo]
        var selectedTabId: String
    }

    var body: some View {
        WithViewStore(
            store,
            observe: { TabBarState(
                tabs: $0.chatTapGroup.tabs,
                tabInfo: $0.chatTapGroup.tabInfo,
                selectedTabId: $0.chatTapGroup.selectedTabId
                    ?? $0.chatTapGroup.tabInfo.first?.id ?? ""
            ) }
        ) { viewStore in
            HStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 0) {
                            ForEach(viewStore.state.tabInfo, id: \.id) { info in
                                ChatTabBarButton(
                                    store: store,
                                    info: info,
                                    isSelected: info.id == viewStore.state.selectedTabId
                                )
                                .id(info.id)
                                .contextMenu {
                                    if let tab = viewStore.state.tabs
                                        .first(where: { $0.id == info.id })
                                    {
                                        tab.menu
                                    }
                                }
                            }
                        }
                    }
                    .hideScrollIndicator()
                    .onChange(of: viewStore.selectedTabId) { id in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(id)
                        }
                    }
                }

                Divider()

                createButton
            }
        }
        .background {
            Button(action: { store.send(.switchToNextTab) }) { EmptyView() }
                .opacity(0)
                .keyboardShortcut("]", modifiers: [.command, .shift])
            Button(action: { store.send(.switchToPreviousTab) }) { EmptyView() }
                .opacity(0)
                .keyboardShortcut("[", modifiers: [.command, .shift])
        }
    }

    @ViewBuilder
    var createButton: some View {
        Menu {
            WithViewStore(store, observe: { $0.chatTapGroup.tabCollection }) { viewStore in
                ForEach(0..<viewStore.state.endIndex, id: \.self) { index in
                    switch viewStore.state[index] {
                    case let .kind(kind):
                        Button(action: {
                            store.send(.createNewTapButtonClicked(kind: kind))
                        }) {
                            Text(kind.title)
                        }
                    case let .folder(title, list):
                        Menu {
                            ForEach(0..<list.endIndex, id: \.self) { index in
                                Button(action: {
                                    store
                                        .send(
                                            .createNewTapButtonClicked(
                                                kind: list[index]
                                            )
                                        )
                                }) {
                                    Text(list[index].title)
                                }
                            }
                        } label: {
                            Text(title)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "plus")
        } primaryAction: {
            store.send(.createNewTapButtonClicked(kind: nil))
        }
        .foregroundColor(.secondary)
        .menuStyle(.borderedButton)
        .padding(.horizontal, 4)
        .fixedSize(horizontal: true, vertical: false)
        .onHover { isHovering in
            if isHovering {
                store.send(.createNewTapButtonHovered)
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
                    .padding(.horizontal, 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

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

struct CreateOtherChatTabMenuStyle: MenuStyle {
    func makeBody(configuration: Configuration) -> some View {
        Image(systemName: "chevron.down")
            .resizable()
            .frame(width: 7, height: 4)
            .frame(maxHeight: .infinity)
            .padding(.leading, 4)
            .padding(.trailing, 8)
            .foregroundColor(.secondary)
    }
}

class FakeChatTab: ChatTab {
    static var name: String { "Fake" }
    static func chatBuilders(externalDependency: Void) -> [ChatTabBuilder] { [Builder()] }

    struct Builder: ChatTabBuilder {
        var title: String = "Title"

        func build() -> any ChatTab {
            return FakeChatTab(id: "id", title: "Title")
        }
    }

    func buildMenu() -> any View {
        Text("Menu Item")
        Text("Menu Item")
        Text("Menu Item")
    }

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

struct ChatWindowView_Previews: PreviewProvider {
    static var previews: some View {
        ChatWindowView(
            store: .init(
                initialState: .init(
                    chatTapGroup: .init(
                        tabs: [
                            FakeChatTab(id: "1", title: "Hello I am a chatbot"),
                            EmptyChatTab(id: "2"),
                            EmptyChatTab(id: "3"),
                            EmptyChatTab(id: "4"),
                            EmptyChatTab(id: "5"),
                            EmptyChatTab(id: "6"),
                            EmptyChatTab(id: "7"),
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

