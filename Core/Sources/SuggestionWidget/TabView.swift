import SwiftUI

struct TabView: View {
    @ObservedObject var chatWindowViewModel: ChatWindowViewModel
    @AppStorage(\.chatPanelInASeparateWindow) var chatPanelInASeparateWindow

    var body: some View {
        Button(action: {
            chatWindowViewModel.chatPanelInASeparateWindow = false
        }, label: {
            Image(systemName: "ellipsis.bubble.fill")
                .frame(width: Style.widgetWidth, height: Style.widgetHeight)
                .background(
                    Color.userChatContentBackground,
                    in: Circle()
                )
        })
        .buttonStyle(.plain)
        .opacity(chatPanelInASeparateWindow ? 1 : 0)
        .preferredColorScheme(chatWindowViewModel.colorScheme)
        .frame(maxWidth: Style.widgetWidth, maxHeight: Style.widgetHeight)
    }
}

struct TabView_Preview: PreviewProvider {
    static var previews: some View {
        VStack {
            TabView(chatWindowViewModel: .init())
        }
        .frame(width: 30)
        .background(Color.black)
    }
}
