import SwiftUI

struct TabView: View {
    @ObservedObject var panelViewModel: SuggestionPanelViewModel

    var body: some View {
        Group {
            switch panelViewModel.activeTab {
            case .chat:
                if panelViewModel.content != nil {
                    Button(action: {
                        
                            panelViewModel.activeTab = .suggestion
                    }, label: {
                        Image(systemName: "lightbulb.fill")
                            .frame(width: Style.widgetWidth, height: Style.widgetHeight)
                            .background(
                                Color.userChatContentBackground,
                                in: Circle()
                            )
                    })
                    .buttonStyle(.plain)
                }
            case .suggestion:
                if panelViewModel.chat != nil {
                    Button(action: {
                        if panelViewModel.chatPanelInASeparateWindow {
                            panelViewModel.chatPanelInASeparateWindow = false
                            panelViewModel.activeTab = .chat
                        } else {
                            panelViewModel.activeTab = .chat
                        }
                    }, label: {
                        Image(systemName: "ellipsis.bubble.fill")
                            .frame(width: Style.widgetWidth, height: Style.widgetHeight)
                            .background(
                                Color.userChatContentBackground,
                                in: Circle()
                            )
                    })
                    .buttonStyle(.plain)
                }
            }
        }
        .opacity(panelViewModel.isPanelDisplayed ? 1 : 0)
        .preferredColorScheme(panelViewModel.colorScheme)
        .frame(maxWidth: Style.widgetWidth, maxHeight: Style.widgetHeight)
    }
}

struct TabView_Preview: PreviewProvider {
    static var previews: some View {
        VStack {
            TabView(panelViewModel: .init())
        }
        .frame(width: 30)
        .background(Color.black)
    }
}
