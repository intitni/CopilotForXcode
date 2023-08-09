import Client
import HostApp
import LaunchAgentManager
import SwiftUI
import UpdateChecker
import XPCShared

struct VisualEffect: NSViewRepresentable {
  func makeNSView(context: Self.Context) -> NSView { return NSVisualEffectView() }
  func updateNSView(_ nsView: NSView, context: Context) { }
}

@main
struct CopilotForXcodeApp: App {
    var body: some Scene {
        WindowGroup {
            TabContainer()
                .frame(minWidth: 800, minHeight: 600)
                .background(VisualEffect().ignoresSafeArea())
                .onAppear {
                    UserDefaults.setupDefaultSettings()
                }
                .environment(\.updateChecker, UpdateChecker(hostBundle: Bundle.main))
        }
    }
}

var isPreview: Bool { ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" }

