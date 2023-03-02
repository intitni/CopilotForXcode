import SwiftUI
import XPCShared

@main
struct CopilotForXcodeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 500, minHeight: 700)
                .preferredColorScheme(.dark)
                .onAppear {
                    UserDefaults.setupDefaultSettings()
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
}

var isPreview: Bool { ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" }
