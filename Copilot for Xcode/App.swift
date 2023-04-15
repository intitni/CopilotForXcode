import Client
import SwiftUI
import UpdateChecker
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
                    Task {
                        let service = try getService()
                        await service.boostQoS()
                    }
                }
                .environment(\.updateChecker, UpdateChecker(hostBundle: Bundle.main))
        }
        .windowStyle(.hiddenTitleBar)
    }
}

var isPreview: Bool { ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" }

struct UpdateCheckerKey: EnvironmentKey {
    static var defaultValue: UpdateChecker = .init(hostBundle: nil)
}

extension EnvironmentValues {
    var updateChecker: UpdateChecker {
        get { self[UpdateCheckerKey.self] }
        set { self[UpdateCheckerKey.self] = newValue }
    }
}
