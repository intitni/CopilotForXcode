import SwiftUI

@main
struct CopilotForXcodeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 500, maxWidth: .infinity, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

var isPreview: Bool { ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" }
