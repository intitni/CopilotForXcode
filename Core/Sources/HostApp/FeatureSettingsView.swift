import SwiftUI

struct FeatureSettingsView: View {
    @State var tag = 0

    var body: some View {
        SidebarTabView(tag: $tag) { tag in
            ScrollView {
                SuggestionSettingsView()
            }
            .padding()
            .sidebarItem(
                tag: 0,
                currentTag: tag,
                title: "Suggestion",
                subtitle: "Generate suggestions for your code",
                image: "lightbulb.circle.fill"
            )

            ScrollView {
                SuggestionSettingsView()
            }
            .padding()
            .sidebarItem(
                tag: 1,
                currentTag: tag,
                title: "Chat",
                subtitle: "Chat about your code",
                image: "bubble.right.circle.fill"
            )

            ScrollView {
                SuggestionSettingsView()
            }
            .padding()
            .sidebarItem(
                tag: 2,
                currentTag: tag,
                title: "Prompt to Code",
                subtitle: "Write code with natural language",
                image: "square.and.pencil.circle.fill"
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

