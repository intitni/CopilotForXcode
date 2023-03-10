import AppKit
import FeedKit
import Foundation
import Logger
import SwiftUI

let skippedUpdateVersionKey = "skippedUpdateVersion"

public struct UpdateChecker {
    var skippedUpdateVersion: String? {
        UserDefaults.standard.string(forKey: skippedUpdateVersionKey)
    }

    public init() {}

    public func checkForUpdate() {
        let url = URL(string: "https://github.com/intitni/CopilotForXcode/releases.atom")!
        let parser = FeedParser(URL: url)
        parser.parseAsync { result in
            switch result {
            case let .success(.atom(feed)):
                if let entry = feed.entries?.first(where: {
                    guard let title = $0.title else { return false }
                    return !title.contains("-")
                }) {
                    self.alertIfUpdateAvailable(entry)
                }
            case let .failure(error):
                Logger.updateChecker.error(error)
            default: break
            }
        }
    }

    func alertIfUpdateAvailable(_ entry: AtomFeedEntry) {
        guard let version = entry.title,
              let currentVersion = Bundle.main
              .infoDictionary?["CFBundleShortVersionString"] as? String,
              version != skippedUpdateVersion,
              version.compare(currentVersion, options: .numeric) == .orderedDescending
        else { return }

        Task { @MainActor in
            let screenFrame = NSScreen.main?.frame ?? .zero
            let window = NSWindow(
                contentRect: .init(
                    x: screenFrame.midX,
                    y: screenFrame.midY + 200,
                    width: 500,
                    height: 500
                ),
                styleMask: .borderless,
                backing: .buffered,
                defer: true
            )
            window.level = .floating
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(
                rootView: AlertView(entry: entry, window: window)
            )
            window.makeKeyAndOrderFront(nil)
        }
    }
}

struct AlertView: View {
    let entry: AtomFeedEntry
    let window: NSWindow

    var body: some View {
        let version = entry.title ?? "0.0.0"
        Color.clear.alert(
            "Copilot for Xcode \(version) is available!",
            isPresented: .constant(true)
        ) {
            Button {
                if let url = URL(string: entry.links?.first?.attributes?.href ?? "") {
                    NSWorkspace.shared.open(url)
                }
                window.close()
            } label: {
                Text("Visit Release Page")
            }

            Button {
                UserDefaults.standard.set(version, forKey: skippedUpdateVersionKey)
                window.close()
            } label: {
                Text("Skip This Version")
            }

            Button { window.close() } label: { Text("Cancel") }
        } message: {
            Text("Would you like to visit the release page?")
        }
    }
}
