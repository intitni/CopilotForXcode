import Foundation
import SwiftUI

enum Tab: Int, CaseIterable, Equatable {
    case general
    case account
    case feature
    case customCommand
    case debug
}

struct TabContainer: View {
    @State var tab = Tab.customCommand

    var body: some View {
        VStack(spacing: 0) {
            TabBar(tab: $tab)
                .padding(.bottom, 8)
            
            Divider()

            Group {
                switch tab {
                case .general:
                    GeneralView()
                case .account:
                    AccountView()
                case .feature:
                    FeatureSettingsView()
                case .customCommand:
                    CustomCommandView()
                case .debug:
                    DebugSettingsView()
                }
            }
            .frame(minHeight: 400)
        }
        .padding(.top, 8)
    }
}

struct TabBar: View {
    @Binding var tab: Tab

    var body: some View {
        HStack {
            ForEach(Tab.allCases, id: \.self) { tab in
                switch tab {
                case .general:
                    TabBarButton(
                        currentTab: $tab,
                        title: "General",
                        image: "app.gift",
                        tab: tab
                    )
                case .account:
                    TabBarButton(currentTab: $tab, title: "Account", image: "person", tab: tab)
                case .feature:
                    TabBarButton(
                        currentTab: $tab,
                        title: "Feature",
                        image: "star.square.on.square",
                        tab: tab
                    )
                case .customCommand:
                    TabBarButton(
                        currentTab: $tab,
                        title: "Custom Command",
                        image: "puzzlepiece.extension",
                        tab: tab
                    )
                case .debug:
                    TabBarButton(currentTab: $tab, title: "Advanced", image: "gearshape.2", tab: tab)
                }
            }
        }
    }
}

struct TabBarButton: View {
    @Binding var currentTab: Tab
    @State var isHovered = false
    var title: String
    var image: String
    var tab: Tab

    var body: some View {
        Button(action: {
            self.currentTab = tab
        }) {
            VStack(spacing: 2) {
                Image(systemName: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 18)
                Text(title)
            }
            .font(.body)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .padding(.top, 4)
            .background(
                tab == currentTab
                    ? Color(nsColor: .textColor).opacity(0.1)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .background(
                isHovered
                    ? Color(nsColor: .textColor).opacity(0.05)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .onHover(perform: { yes in
            isHovered = yes
        })
        .buttonStyle(.borderless)
    }
}

struct TabContainer_Previews: PreviewProvider {
    static var previews: some View {
        TabContainer()
            .frame(width: 800)
    }
}

