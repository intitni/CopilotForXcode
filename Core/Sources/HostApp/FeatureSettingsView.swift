import SwiftUI

struct FeatureSettingsView: View {
    @State var tag = 0

    var body: some View {
        SidebarTabView(tag: $tag) { 
            ScrollView {
                SuggestionSettingsView()
            }
            .padding()
            .sidebarItem(
                tag: 0,
                title: "Suggestion",
                subtitle: "Generate suggestions for your code",
                image: "lightbulb"
            )

            ScrollView {
                ChatSettingsView()
            }
            .padding()
            .sidebarItem(
                tag: 1,
                title: "Chat",
                subtitle: "Chat about your code",
                image: "character.bubble"
            )

            ScrollView {
                PromptToCodeSettingsView()
            }
            .padding()
            .sidebarItem(
                tag: 2,
                title: "Prompt to Code",
                subtitle: "Write code with natural language",
                image: "paintbrush"
            )
        }
    }
}

struct FeatureSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        FeatureSettingsView()
            .frame(width: 800)
    }
}

