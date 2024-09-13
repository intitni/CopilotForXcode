import ComposableArchitecture
import Dependencies
import Foundation
import LaunchAgentManager
import SharedUIComponents
import SwiftUI
import Toast
import UpdateChecker

@MainActor
let hostAppStore: StoreOf<HostApp> = .init(initialState: .init(), reducer: { HostApp() })

public struct TabContainer: View {
    let store: StoreOf<HostApp>
    @ObservedObject var toastController: ToastController
    @State private var tabBarItems = [TabBarItem]()
    @State var tag: Int = 0

    var externalTabContainer: ExternalTabContainer {
        ExternalTabContainer.tabContainer(for: "TabContainer")
    }

    public init() {
        toastController = ToastControllerDependencyKey.liveValue
        store = hostAppStore
    }

    init(store: StoreOf<HostApp>, toastController: ToastController) {
        self.store = store
        self.toastController = toastController
    }

    public var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                TabBar(tag: $tag, tabBarItems: tabBarItems)
                    .padding(.bottom, 8)

                Divider()

                ZStack(alignment: .center) {
                    GeneralView(store: store.scope(state: \.general, action: \.general))
                        .tabBarItem(
                            tag: 0,
                            title: "General",
                            image: "app.gift"
                        )
                    ServiceView(store: store).tabBarItem(
                        tag: 1,
                        title: "Service",
                        image: "globe"
                    )
                    FeatureSettingsView().tabBarItem(
                        tag: 2,
                        title: "Feature",
                        image: "star.square"
                    )
                    CustomCommandView(store: customCommandStore).tabBarItem(
                        tag: 3,
                        title: "Custom Command",
                        image: "command.square"
                    )
                    
                    ForEach(0..<externalTabContainer.tabs.endIndex, id: \.self) { index in
                        let tab = externalTabContainer.tabs[index]
                        tab.viewBuilder().tabBarItem(
                            tag: 5 + index,
                            title: tab.title,
                            image: "plus.diamond"
                        )
                    }
                    
                    DebugSettingsView().tabBarItem(
                        tag: 4,
                        title: "Advanced",
                        image: "gearshape.2"
                    )
                }
                .environment(\.tabBarTabTag, tag)
                .frame(minHeight: 400)
            }
            .focusable(false)
            .padding(.top, 8)
            .background(.ultraThinMaterial.opacity(0.01))
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
            .handleToast()
            .onPreferenceChange(TabBarItemPreferenceKey.self) { items in
                tabBarItems = items
            }
            .onAppear {
                store.send(.appear)
            }
        }
    }
}

struct TabBar: View {
    @Binding var tag: Int
    fileprivate var tabBarItems: [TabBarItem]

    var body: some View {
        HStack {
            ForEach(tabBarItems) { tab in
                TabBarButton(
                    currentTag: $tag,
                    tag: tab.tag,
                    title: tab.title,
                    image: tab.image
                )
            }
        }
    }
}

struct TabBarButton: View {
    @Binding var currentTag: Int
    @State var isHovered = false
    var tag: Int
    var title: String
    var image: String

    var body: some View {
        Button(action: {
            self.currentTag = tag
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
                tag == currentTag
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

private struct TabBarTabViewWrapper<Content: View>: View {
    @Environment(\.tabBarTabTag) var tabBarTabTag
    var tag: Int
    var title: String
    var image: String
    var content: () -> Content

    var body: some View {
        Group {
            if tag == tabBarTabTag {
                content()
            } else {
                Color.clear
            }
        }
        .preference(
            key: TabBarItemPreferenceKey.self,
            value: [.init(tag: tag, title: title, image: image)]
        )
    }
}

private extension View {
    func tabBarItem(
        tag: Int,
        title: String,
        image: String
    ) -> some View {
        TabBarTabViewWrapper(
            tag: tag,
            title: title,
            image: image,
            content: { self }
        )
    }
}

private struct TabBarItem: Identifiable, Equatable {
    var id: Int { tag }
    var tag: Int
    var title: String
    var image: String
}

private struct TabBarItemPreferenceKey: PreferenceKey {
    static var defaultValue: [TabBarItem] = []
    static func reduce(value: inout [TabBarItem], nextValue: () -> [TabBarItem]) {
        value.append(contentsOf: nextValue())
    }
}

private struct TabBarTabTagKey: EnvironmentKey {
    static var defaultValue: Int = 0
}

private extension EnvironmentValues {
    var tabBarTabTag: Int {
        get { self[TabBarTabTagKey.self] }
        set { self[TabBarTabTagKey.self] = newValue }
    }
}

struct UpdateCheckerKey: EnvironmentKey {
    static var defaultValue: UpdateChecker = .init(
        hostBundle: nil,
        shouldAutomaticallyCheckForUpdate: false
    )
}

public extension EnvironmentValues {
    var updateChecker: UpdateChecker {
        get { self[UpdateCheckerKey.self] }
        set { self[UpdateCheckerKey.self] = newValue }
    }
}

// MARK: - Previews

struct TabContainer_Previews: PreviewProvider {
    static var previews: some View {
        TabContainer()
            .frame(width: 800)
    }
}

struct TabContainer_Toasts_Previews: PreviewProvider {
    static var previews: some View {
        TabContainer(
            store: .init(initialState: .init(), reducer: { HostApp() }),
            toastController: .init(messages: [
                .init(id: UUID(), type: .info, content: Text("info")),
                .init(id: UUID(), type: .error, content: Text("error")),
                .init(id: UUID(), type: .warning, content: Text("warning")),
            ])
        )
        .frame(width: 800)
    }
}

