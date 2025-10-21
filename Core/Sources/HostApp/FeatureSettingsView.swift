import SwiftUI
import SharedUIComponents

struct FeatureSettingsView: View {
    var tabContainer: ExternalTabContainer {
        ExternalTabContainer.tabContainer(for: "Features")
    }
    
    @State var tag = 0

    var body: some View {
        SidebarTabView(tag: $tag) {
            SuggestionSettingsView()
                .sidebarItem(
                    tag: 0,
                    title: "Suggestion",
                    subtitle: "Generate suggestions for your code",
                    image: "lightbulb"
                )

            ChatSettingsView()
                .sidebarItem(
                    tag: 1,
                    title: "Chat",
                    subtitle: "Chat about your code",
                    image: "character.bubble"
                )

            ScrollView {
                PromptToCodeSettingsView().padding()
            }
            .sidebarItem(
                tag: 2,
                title: "Modification",
                subtitle: "Write or modify code with natural language",
                image: "paintbrush"
            )

            ScrollView {
                XcodeSettingsView().padding()
            }
            .sidebarItem(
                tag: 3,
                title: "Xcode",
                subtitle: "Xcode related features",
                image: "app"
            )
            
            ForEach(Array(tabContainer.tabs.enumerated()), id: \.1.id) { index, tab in
                ScrollView {
                    tab.viewBuilder().padding()
                }
                .sidebarItem(
                    tag: 4 + index,
                    title: tab.title,
                    subtitle: tab.description,
                    image: tab.image
                )
            }
        }
    }
}

struct FeatureSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        FeatureSettingsView()
            .frame(width: 800)
    }
}
