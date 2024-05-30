import Client
import HostApp
import LaunchAgentManager
import SwiftUI
import UpdateChecker
import XPCShared

struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Self.Context) -> NSView { return NSVisualEffectView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

class TheUpdateCheckerDelegate: UpdateCheckerDelegate {
    func prepareForRelaunch(finish: @escaping () -> Void) {
        Task {
            let service = try? getService()
            try? await service?.quitService()
            finish()
        }
    }
}

let updateCheckerDelegate = TheUpdateCheckerDelegate()

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
                .environment(
                    \.updateChecker,
                    {
                        let checker = UpdateChecker(
                            hostBundle: Bundle.main,
                            shouldAutomaticallyCheckForUpdate: false
                        )
                        checker.updateCheckerDelegate = updateCheckerDelegate
                        return checker
                    }()
                )
        }
    }
}

var isPreview: Bool { ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" }

