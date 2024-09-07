import ActiveApplicationMonitor
import AppKit
import ChatGPTChatTab
import ChatTab
import ComposableArchitecture
import SwiftUI

private let r: Double = 8

struct ChatWindowView: View {
    let store: StoreOf<ChatPanel>
    let toggleVisibility: (Bool) -> Void

    var body: some View {
        WithPerceptionTracking {
            let _ = store.chatTabGroup.selectedTabId // force re-evaluation
            VStack(spacing: 0) {
                Rectangle().fill(.regularMaterial).frame(height: 28)

                Divider()

                ChatTabBar(store: store)
                    .frame(height: 26)

                Divider()

                ChatTabContainer(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .xcodeStyleFrame(cornerRadius: 10)
            .ignoresSafeArea(edges: .top)
            .onChange(of: store.isPanelDisplayed) { isDisplayed in
                toggleVisibility(isDisplayed)
            }
            .preferredColorScheme(store.colorScheme)
        }
    }
}

struct ChatTitleBar: View {
    let store: StoreOf<ChatPanel>
    @State var isHovering = false

    var body: some View {
        WithPerceptionTracking {
            HStack(spacing: 6) {
                Button(action: {
                    store.send(.closeActiveTabClicked)
                }) {
                    EmptyView()
                }
                .opacity(0)
                .keyboardShortcut("w", modifiers: [.command])

                Button(
                    action: {
                        store.send(.hideButtonClicked)
                    }
                ) {
                    Image(systemName: "minus")
                        .foregroundStyle(.black.opacity(0.5))
                        .font(Font.system(size: 8).weight(.heavy))
                }
                .opacity(0)
                .keyboardShortcut("m", modifiers: [.command])

                Spacer()

                TrafficLightButton(
                    isHovering: isHovering,
                    isActive: store.isDetached,
                    color: Color(nsColor: .systemCyan),
                    action: {
                        store.send(.toggleChatPanelDetachedButtonClicked)
                    }
                ) {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.black.opacity(0.5))
                        .font(Font.system(size: 6).weight(.black))
                        .transformEffect(.init(translationX: 0, y: 0.5))
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
            .onHover(perform: { hovering in
                isHovering = hovering
            })
        }
    }

    struct TrafficLightButton<Icon: View>: View {
        let isHovering: Bool
        let isActive: Bool
        let color: Color
        let action: () -> Void
        let icon: () -> Icon

        @Environment(\.controlActiveState) var controlActiveState

        var body: some View {
            Button(action: {
                action()
            }) {
                Circle()
                    .fill(
                        controlActiveState == .key && isActive
                            ? color
                            : Color(nsColor: .separatorColor)
                    )
                    .frame(
                        width: Style.trafficLightButtonSize,
                        height: Style.trafficLightButtonSize
                    )
                    .overlay {
                        Circle().stroke(lineWidth: 0.5).foregroundColor(.black.opacity(0.2))
                    }
                    .overlay {
                        if isHovering {
                            icon()
                        }
                    }
            }
            .focusable(false)
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
    let store: StoreOf<ChatPanel>

    struct TabBarState: Equatable {
        var tabInfo: IdentifiedArray<String, ChatTabInfo>
        var selectedTabId: String
    }

    var body: some View {
        HStack(spacing: 0) {
            Divider()
            Tabs(store: store)
            CreateButton(store: store)
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

    struct Tabs: View {
        let store: StoreOf<ChatPanel>
        @State var draggingTabId: String?
        @Environment(\.chatTabPool) var chatTabPool

        var body: some View {
            WithPerceptionTracking {
                let tabInfo = store.chatTabGroup.tabInfo
                let selectedTabId = store.chatTabGroup.selectedTabId
                    ?? store.chatTabGroup.tabInfo.first?.id
                    ?? ""
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 0) {
                            ForEach(tabInfo, id: \.id) { info in
                                WithPerceptionTracking {
                                    if let tab = chatTabPool.getTab(of: info.id) {
                                        ChatTabBarButton(
                                            store: store,
                                            info: info,
                                            content: { tab.tabItem },
                                            icon: { tab.icon },
                                            isSelected: info.id == selectedTabId
                                        )
                                        .contextMenu {
                                            tab.menu
                                        }
                                        .id(info.id)
                                        .onDrag {
                                            draggingTabId = info.id
                                            return NSItemProvider(object: info.id as NSString)
                                        }
                                        .onDrop(
                                            of: [.text],
                                            delegate: ChatTabBarDropDelegate(
                                                store: store,
                                                tabs: tabInfo,
                                                itemId: info.id,
                                                draggingTabId: $draggingTabId
                                            )
                                        )
                                        
                                    } else {
                                        ChatTabBarButton(
                                            store: store,
                                            info: info,
                                            content: { Text("Not Found") },
                                            icon: { Image(systemName: "questionmark.diamond") },
                                            isSelected: info.id == selectedTabId
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .hideScrollIndicator()
                    .onChange(of: selectedTabId) { id in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(id)
                        }
                    }
                }
            }
        }
    }

    struct CreateButton: View {
        let store: StoreOf<ChatPanel>

        var body: some View {
            WithPerceptionTracking {
                let collection = store.chatTabGroup.tabCollection
                Menu {
                    ForEach(0..<collection.endIndex, id: \.self) { index in
                        WithPerceptionTracking {
                            switch collection[index] {
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
                                            store.send(
                                                .createNewTapButtonClicked(kind: list[index])
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
    }
}

struct ChatTabBarDropDelegate: DropDelegate {
    let store: StoreOf<ChatPanel>
    let tabs: IdentifiedArray<String, ChatTabInfo>
    let itemId: String
    @Binding var draggingTabId: String?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingTabId = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard itemId != draggingTabId else { return }
        let from = tabs.firstIndex { $0.id == draggingTabId }
        let to = tabs.firstIndex { $0.id == itemId }
        guard let from, let to, from != to else { return }
        store.send(.moveChatTab(from: from, to: to))
    }
}

struct ChatTabBarButton<Content: View, Icon: View>: View {
    let store: StoreOf<ChatPanel>
    let info: ChatTabInfo
    let content: () -> Content
    let icon: () -> Icon
    let isSelected: Bool
    @State var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                icon().foregroundColor(.secondary)
                content()
            }
            .font(.callout)
            .lineLimit(1)
            .frame(maxWidth: 120)
            .padding(.horizontal, 28)
            .contentShape(Rectangle())
            .onTapGesture {
                store.send(.tabClicked(id: info.id))
            }
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
    let store: StoreOf<ChatPanel>
    @Environment(\.chatTabPool) var chatTabPool

    var body: some View {
        WithPerceptionTracking {
            let tabInfo = store.chatTabGroup.tabInfo
            let selectedTabId = store.chatTabGroup.selectedTabId
                ?? store.chatTabGroup.tabInfo.first?.id
                ?? ""

            ZStack {
                if tabInfo.isEmpty {
                    Text("Empty")
                } else {
                    ForEach(tabInfo) { tabInfo in
                        if let tab = chatTabPool.getTab(of: tabInfo.id) {
                            let isActive = tab.id == selectedTabId
                            tab.body
                                .opacity(isActive ? 1 : 0)
                                .disabled(!isActive)
                                .allowsHitTesting(isActive)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                // move it out of window
                                .rotationEffect(
                                    isActive ? .zero : .degrees(90),
                                    anchor: .topLeading
                                )
                        } else {
                            Text("404 Not Found")
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

    static func createStore() -> StoreOf<ChatPanel> {
        StoreOf<ChatPanel>(
            initialState: .init(
                chatTabGroup: .init(
                    tabInfo: [
                        .init(id: "2", title: "Empty-2"),
                        .init(id: "3", title: "Empty-3"),
                        .init(id: "4", title: "Empty-4"),
                        .init(id: "5", title: "Empty-5"),
                        .init(id: "6", title: "Empty-6"),
                        .init(id: "7", title: "Empty-7"),
                    ] as IdentifiedArray<String, ChatTabInfo>,
                    selectedTabId: "2"
                ),
                isPanelDisplayed: true
            ),
            reducer: { ChatPanel() }
        )
    }

    static var previews: some View {
        ChatWindowView(store: createStore(), toggleVisibility: { _ in })
            .xcodeStyleFrame()
            .padding()
            .environment(\.chatTabPool, pool)
    }
}

