import SwiftUI

struct ChatSettingsView: View {
    class Settings: ObservableObject {
        @AppStorage(\.chatFontSize) var chatFontSize
        @AppStorage(\.chatCodeFontSize) var chatCodeFontSize
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
        }
    }
}
