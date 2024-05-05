import SwiftUI
import Client

struct ContentView: View {
    @State var text: String = "Hello, world!"
    var body: some View {
        VStack {
            Button(action: {
                Task {
                    do {
                        let service = try getService()
                        let version = try await service.getXPCServiceVersion()
                        text = "Version: \(version.version) Build: \(version.build)"
                    } catch {
                        text = error.localizedDescription
                    }
                }
            }) {
                Text("Test")
            }
            Text(text)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
