import ComposableArchitecture
import SwiftUI

struct TabView: View {
    let store: StoreOf<ChatPanelFeature>

    struct State: Equatable {
        var chatPanelInASeparateWindow: Bool
        var colorScheme: ColorScheme
    }

    var body: some View {
        WithViewStore(
            store,
            observe: {
                State(
                    chatPanelInASeparateWindow: $0.chatPanelInASeparateWindow,
                    colorScheme: $0.colorScheme
                )
            }
        ) { viewStore in
            Button(action: {
                viewStore.send(.toggleChatPanelDetachedButtonClicked)
            }, label: {
                Image(systemName: "ellipsis.bubble.fill")
                    .frame(width: Style.widgetWidth, height: Style.widgetHeight)
                    .background(
                        Color.userChatContentBackground,
                        in: Circle()
                    )
            })
            .buttonStyle(.plain)
            .opacity(viewStore.chatPanelInASeparateWindow ? 1 : 0)
            .preferredColorScheme(viewStore.colorScheme)
            .frame(maxWidth: Style.widgetWidth, maxHeight: Style.widgetHeight)
        }
    }
}

struct TabView_Preview: PreviewProvider {
    static var previews: some View {
        VStack {
            TabView(store: .init(initialState: .init(), reducer: ChatPanelFeature()))
        }
        .frame(width: 30)
        .background(Color.black)
    }
}

