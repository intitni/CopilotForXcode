import SwiftUI

struct AccountView: View {
    @State var tag = 0
    var body: some View {
        SidebarTabView(tag: $tag) { tag in
            ScrollView {
                CopilotView().padding()
            }.sidebarItem(
                tag: 0,
                currentTag: tag,
                title: "GitHub Copilot",
                subtitle: "Suggestion",
                image: "person.circle.fill"
            )
            
            ScrollView {
                OpenAIView().padding()
            }.sidebarItem(
                tag: 1,
                currentTag: tag,
                title: "OpenAI",
                subtitle: "Chat, Prompt to Code",
                image: "person.circle.fill"
            )
        }
    }
}

struct AccountView_Previews: PreviewProvider {
    static var previews: some View {
        AccountView()
    }
}

