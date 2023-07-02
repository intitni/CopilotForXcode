import ActiveApplicationMonitor
import AppKit
import ChatTab
import ComposableArchitecture
import SwiftUI

private let r: Double = 8

struct ChatWindowView: View {
    let store: StoreOf<ChatPanelFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            Group {
                if let chat = viewStore.chat {
                    ChatPanel(chat: chat)
                        .background {
                            Button(action: {
                                viewStore.send(.hideButtonClicked)
                            }) {
                                EmptyView()
                            }
                            .keyboardShortcut("M", modifiers: [.command])
                        }
                }
            }
            .xcodeStyleFrame()
            .opacity(viewStore.isPanelDisplayed ? 1 : 0)
            .frame(minWidth: Style.panelWidth, minHeight: Style.panelHeight)
            .preferredColorScheme(viewStore.colorScheme)
        }
    }
}

