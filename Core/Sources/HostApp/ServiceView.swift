import ComposableArchitecture
import SwiftUI

struct ServiceView: View {
    let store: StoreOf<HostApp>
    @State var tag = 0

    var body: some View {
        WithPerceptionTracking {
            SidebarTabView(tag: $tag) {
                WithPerceptionTracking {
                    ScrollView {
                        GitHubCopilotView().padding()
                    }.sidebarItem(
                        tag: 0,
                        title: "GitHub Copilot",
                        subtitle: "Suggestion",
                        image: "globe"
                    )
                    
                    ScrollView {
                        CodeiumView().padding()
                    }.sidebarItem(
                        tag: 1,
                        title: "Codeium",
                        subtitle: "Suggestion",
                        image: "globe"
                    )
                    
                    ChatModelManagementView(store: store.scope(
                        state: \.chatModelManagement,
                        action: \.chatModelManagement
                    )).sidebarItem(
                        tag: 2,
                        title: "Chat Models",
                        subtitle: "Chat, Modification",
                        image: "globe"
                    )
                    
                    EmbeddingModelManagementView(store: store.scope(
                        state: \.embeddingModelManagement,
                        action: \.embeddingModelManagement
                    )).sidebarItem(
                        tag: 3,
                        title: "Embedding Models",
                        subtitle: "Chat, Modification",
                        image: "globe"
                    )
                    
                    ScrollView {
                        BingSearchView().padding()
                    }.sidebarItem(
                        tag: 4,
                        title: "Bing Search",
                        subtitle: "Search Chat Plugin",
                        image: "globe"
                    )
                    
                    ScrollView {
                        OtherSuggestionServicesView().padding()
                    }.sidebarItem(
                        tag: 5,
                        title: "Other Suggestion Services",
                        subtitle: "Suggestion",
                        image: "globe"
                    )
                }
            }
        }
    }
}

struct AccountView_Previews: PreviewProvider {
    static var previews: some View {
        ServiceView(store: .init(initialState: .init(), reducer: { HostApp() }))
    }
}

