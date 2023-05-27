import SwiftUI

struct ServiceView: View {
    @State var tag = 0
    var body: some View {
        SidebarTabView(tag: $tag) {
            ScrollView {
                CopilotView().padding()
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
            
            ScrollView {
                OpenAIView().padding()
            }.sidebarItem(
                tag: 2,
                title: "OpenAI",
                subtitle: "Chat, Prompt to Code",
                image: "globe"
            )
            
            ScrollView {
                AzureView().padding()
            }.sidebarItem(
                tag: 3,
                title: "Azure",
                subtitle: "Chat, Prompt to Code",
                image: "globe"
            )
        }
    }
}

struct AccountView_Previews: PreviewProvider {
    static var previews: some View {
        ServiceView()
    }
}
