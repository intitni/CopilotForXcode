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
                    selectedTabId: $0.chatTabGroup.selectedTabId
                )
            }
        ) { viewStore in
            VStack(spacing: 0) {
                ChatTitleBar(store: store)

                Divider()

                ChatTabBar(store: store)
                    .frame(height: 26)

                Divider()

                ChatTabContainer(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(.regularMaterial)
            .xcodeStyleFrame()
            .opacity(viewStore.state.isPanelDisplayed ? 1 : 0)
            .frame(minWidth: Style.panelWidth, minHeight: Style.panelHeight)
            .preferredColorScheme(viewStore.state.colorScheme)
        }
    }
}

struct ChatTitleBar: View {
    let store: StoreOf<ChatPanelFeature>
    @State var isHovering = false
    @Environment(\.controlActiveState) var controlActiveState

    var body: some View {
        HStack(spacing: 4) {
            Button(action: {
                store.send(.hideButtonClicked)
            }) {
                Circle()
                    .fill(
                        controlActiveState == .key
                            ? Color(nsColor: .systemOrange)
                            : Color(nsColor: .disabledControlTextColor)
                    )
                    .frame(width: 10, height: 10)
                    .overlay {
                        Circle().strokeBorder(.black.opacity(0.3), lineWidth: 1)
                    }
                    .overlay {
                        if isHovering {
                            Image(systemName: "minus")
                                .resizable()
                                .foregroundStyle(.black.opacity(0.7))
                                .font(Font.title.weight(.heavy))
                                .frame(width: 5, height: 1)
                        }
                    }
            }

            WithViewStore(store, observe: { $0.chatPanelInASeparateWindow }) { viewStore in
                Button(action: {
                    store.send(.toggleChatPanelDetachedButtonClicked)
                }) {
                    Circle()
                        .fill(
                            controlActiveState == .key && viewStore.state
                                ? Color(nsColor: .systemCyan)
                                : Color(nsColor: .disabledControlTextColor)
                        )
                        .frame(width: 10, height: 10)
                        .overlay {
                            Circle().strokeBorder(.black.opacity(0.3), lineWidth: 1)
                        }
                        .disabled(!viewStore.state)
                        .overlay {
                            if isHovering {
                                Image(systemName: "pin")
                                    .resizable()
                                    .foregroundStyle(.black.opacity(0.7))
                                    .font(Font.title.weight(.heavy))
                                    .frame(width: 4, height: 6)
                                    .transformEffect(.init(translationX: 0, y: 0.5))
                            }
                        }
                }
            }

            Button(action: {
                store.send(.closeActiveTabClicked)
            }) {
                EmptyView()
            }
            .opacity(0)
            .keyboardShortcut("w", modifiers: [.command])

            Spacer()
        }
        .buttonStyle(.plain)
        .overlay {
            RoundedRectangle(cornerRadius: 2)
                .fill(.tertiary)
                .frame(width: 120, height: 4)
                .background {
                    if isHovering {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.tertiary.opacity(0.3))
                            .frame(width: 128, height: 12)
                    }
                }
        }
        .padding(.horizontal, 6)
        .padding(.top, 1)
        .frame(maxWidth: .infinity)
        .frame(height: 16)
        .onHover(perform: { hovering in
            isHovering = hovering
        })
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
        var tabInfo: IdentifiedArray<String, ChatTabInfo>
        var selectedTabId: String
    }

    @Environment(\.chatTabPool) var chatTabPool

    var body: some View {
        WithViewStore(
            store,
            observe: { TabBarState(
                tabInfo: $0.chatTabGroup.tabInfo,
                selectedTabId: $0.chatTabGroup.selectedTabId
                    ?? $0.chatTabGroup.tabInfo.first?.id ?? ""
            ) }
        ) { viewStore in
            HStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 0) {
                            ForEach(viewStore.state.tabInfo, id: \.id) { info in
                                if let tab = chatTabPool.getTab(of: info.id) {
                                    ChatTabBarButton(
                                        store: store,
                                        info: info,
                                        content: { tab.tabItem },
                                        isSelected: info.id == viewStore.state.selectedTabId
                                    )
                                    .contextMenu {
                                        tab.menu
                                    }
                                    .id(info.id)
                                } else {
                                    EmptyView()
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
            WithViewStore(store, observe: { $0.chatTabGroup.tabCollection }) { viewStore in
                ForEach(0..<viewStore.state.endIndex, id: \.self) { index in
                    switch viewStore.state[index] {
                    case let .kind(kind):
                        Button(action: {
                            store.send(.createNewTapButtonClicked(kind: kind))
                        }) {
                            Text(kind.title)
                        }.disabled(kind.builder is DisabledChatTabBuilder)
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

struct ChatTabBarButton<Content: View>: View {
    let store: StoreOf<ChatPanelFeature>
    let info: ChatTabInfo
    let content: () -> Content
    let isSelected: Bool
    @State var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            Button(action: {
                store.send(.tabClicked(id: info.id))
            }) {
                content()
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
        var tabInfo: IdentifiedArray<String, ChatTabInfo>
        var selectedTabId: String?
    }

    @Environment(\.chatTabPool) var chatTabPool

    var body: some View {
        WithViewStore(
            store,
            observe: {
                TabContainerState(
                    tabInfo: $0.chatTabGroup.tabInfo,
                    selectedTabId: $0.chatTabGroup.selectedTabId
                        ?? $0.chatTabGroup.tabInfo.first?.id ?? ""
                )
            }
        ) { viewStore in
            ZStack {
                if viewStore.state.tabInfo.isEmpty {
                    Text("Empty")
                } else {
                    ForEach(viewStore.state.tabInfo) { tabInfo in
                        if let tab = chatTabPool.getTab(of: tabInfo.id) {
                            let isActive = tab.id == viewStore.state.selectedTabId
                            tab.body
                                .opacity(isActive ? 1 : 0)
                                .disabled(!isActive)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            EmptyView()
                        }
                    }
                }
            }
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

struct ChatWindowView_Previews: PreviewProvider {
    static let pool = ChatTabPool([
        "2": EmptyChatTab(id: "2"),
        "3": EmptyChatTab(id: "3"),
        "4": EmptyChatTab(id: "4"),
        "5": EmptyChatTab(id: "5"),
        "6": EmptyChatTab(id: "6"),
        "7": EmptyChatTab(id: "7"),
    ])

    static func createStore() -> StoreOf<ChatPanelFeature> {
        StoreOf<ChatPanelFeature>(
            initialState: .init(
                chatTabGroup: .init(
                    tabInfo: [
                        .init(id: "2", title: "Empty-2"),
                        .init(id: "3", title: "Empty-3"),
                        .init(id: "4", title: "Empty-4"),
                        .init(id: "5", title: "Empty-5"),
                        .init(id: "6", title: "Empty-6"),
                        .init(id: "7", title: "Empty-7"),
                    ],
                    selectedTabId: "2"
                ),
                isPanelDisplayed: true
            ),
            reducer: ChatPanelFeature()
        )
    }

    static var previews: some View {
        ChatWindowView(store: createStore())
            .xcodeStyleFrame()
            .padding()
            .environment(\.chatTabPool, pool)
    }
}

