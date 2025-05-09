import ComposableArchitecture
import Foundation
import SwiftUI

struct PromptToCodePanelGroupView: View {
    let store: StoreOf<PromptToCodeGroup>

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                PromptToCodeTabBar(store: store)
                    .frame(height: 26)

                Divider()

                if let store = self.store.scope(
                    state: \.activePromptToCode,
                    action: \.activePromptToCode
                ) {
                    PromptToCodePanelView(store: store)
                }
            }
            .background(.ultraThickMaterial)
            .xcodeStyleFrame()
        }
    }
}

struct PromptToCodeTabBar: View {
    let store: StoreOf<PromptToCodeGroup>

    struct TabInfo: Equatable, Identifiable {
        var id: URL
        var tabTitle: String
        var isProcessing: Bool
    }

    var body: some View {
        HStack(spacing: 0) {
            Tabs(store: store)
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
        let store: StoreOf<PromptToCodeGroup>

        var body: some View {
            WithPerceptionTracking {
                let tabInfo = store.promptToCodes.map {
                    TabInfo(
                        id: $0.id,
                        tabTitle: $0.filename,
                        isProcessing: $0.promptToCodeState.isGenerating
                    )
                }
                let selectedTabId = store.selectedTabId
                    ?? store.promptToCodes.first?.id

                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 0) {
                            ForEach(tabInfo) { info in
                                WithPerceptionTracking {
                                    PromptToCodeTabBarButton(
                                        store: store,
                                        info: info,
                                        isSelected: info.id == store.selectedTabId
                                    )
                                    .id(info.id)
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
}

struct PromptToCodeTabBarButton: View {
    let store: StoreOf<PromptToCodeGroup>
    let info: PromptToCodeTabBar.TabInfo
    let isSelected: Bool
    @State var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                if info.isProcessing {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(info.tabTitle)
                    .truncationMode(.middle)
                    .allowsTightening(true)
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

