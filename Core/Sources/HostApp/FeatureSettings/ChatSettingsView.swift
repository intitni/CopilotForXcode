import SwiftUI

struct ChatSettingsView: View {
    class Settings: ObservableObject {
        @AppStorage(\.chatFontSize) var chatFontSize
        @AppStorage(\.chatCodeFontSize) var chatCodeFontSize
        @AppStorage(\.embedFileContentInChatContextIfNoSelection)
        var embedFileContentInChatContextIfNoSelection
        @AppStorage(\.maxEmbeddableFileInChatContextLineCount)
        var maxEmbeddableFileInChatContextLineCount
        init() {}
    }
    
    @StateObject var settings = Settings()
    
    var body: some View {
        Form {
            HStack {
                TextField(text: .init(get: {
                    "\(Int(settings.chatFontSize))"
                }, set: {
                    settings.chatFontSize = Double(Int($0) ?? 0)
                })) {
                    Text("Font size of message")
                }
                .textFieldStyle(.roundedBorder)

                Text("pt")
            }
            
            HStack {
                TextField(text: .init(get: {
                    "\(Int(settings.chatCodeFontSize))"
                }, set: {
                    settings.chatCodeFontSize = Double(Int($0) ?? 0)
                })) {
                    Text("Font size of code block")
                }
                .textFieldStyle(.roundedBorder)

                Text("pt")
            }
            
            Divider()
            
            Toggle(isOn: $settings.embedFileContentInChatContextIfNoSelection) {
                Text("Embed file content in chat context if no code is selected.")
            }
            
            HStack {
                TextField(text: .init(get: {
                    "\(Int(settings.maxEmbeddableFileInChatContextLineCount))"
                }, set: {
                    settings.maxEmbeddableFileInChatContextLineCount = Int($0) ?? 0
                })) {
                    Text("Max embeddable file")
                }
                .textFieldStyle(.roundedBorder)

                Text("lines")
            }
        }
    }
}

// MARK: - Preview

struct ChatSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ChatSettingsView()
    }
}
