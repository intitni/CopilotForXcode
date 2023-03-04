import AppKit
import Foundation
import os.log
import SwiftUI

struct Release: Codable {
    let tag_name: String?
    let html_url: String?
    let body: String?
    let published_at: String?
}

let skippedUpdateVersionKey = "skippedUpdateVersion"

public struct UpdateChecker {
    var skippedUpdateVersion: String? {
        UserDefaults.standard.string(forKey: skippedUpdateVersionKey)
    }

    public init() {}

    public func checkForUpdate() async {
        let url =
            URL(string: "https://api.github.com/repos/intitni/CopilotForXcode/releases/latest")!
        do {
            var request = URLRequest(url: url)
            let token = (Bundle.main.infoDictionary?["GITHUB_TOKEN"] as? String) ?? ""
            if !token.isEmpty {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("X-GitHub-Api-Version", forHTTPHeaderField: "2022-11-28")

            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            let release = try decoder.decode(Release.self, from: data)
            guard let version = release.tag_name,
                  version != skippedUpdateVersion,
                  version != Bundle.main
                  .infoDictionary?["CFBundleShortVersionString"] as? String
            else { return }

            Task { @MainActor in
                let alert = NSAlert()
                alert.messageText = "Copilot for Xcode \(version) is available!"
                alert.informativeText = "Would you like to visit the release page?"
                let view = NSHostingView(
                    rootView:
                    AccessoryView(releaseNote: release.body)
                )
                view.frame = .init(origin: .zero, size: .init(width: 400, height: 200))
                alert.accessoryView = view

                alert.addButton(withTitle: "Visit Release Page")
                alert.addButton(withTitle: "Skip This Version")
                alert.addButton(withTitle: "Cancel")
                alert.alertStyle = .informational
                let screenFrame = NSScreen.main?.frame ?? .zero
                let window = NSWindow(
                    contentRect: .init(
                        x: screenFrame.midX,
                        y: screenFrame.midY,
                        width: 1,
                        height: 1
                    ),
                    styleMask: .borderless,
                    backing: .buffered,
                    defer: true
                )
                window.level = .statusBar
                window.isReleasedWhenClosed = false
                alert.beginSheetModal(for: window) { [window] response in
                    switch response {
                    case .alertFirstButtonReturn:
                        if let url = URL(string: release.html_url ?? "") {
                            NSWorkspace.shared.open(url)
                        }
                    case .alertSecondButtonReturn:
                        UserDefaults.standard.set(version, forKey: skippedUpdateVersionKey)
                    default:
                        break
                    }
                    window.close()
                }
            }
        } catch {
            os_log(.error, "%@", error.localizedDescription)
        }
    }
}

struct AccessoryView: View {
    let releaseNote: String?

    var body: some View {
        if let releaseNote {
            ScrollView {
                Text(releaseNote)
                    .padding()

                Spacer()
            }
            .background(Color(nsColor: .textBackgroundColor))
            .overlay {
                Rectangle()
                    .stroke(Color(nsColor: .separatorColor), style: .init(lineWidth: 2))
            }
        } else {
            EmptyView()
        }
    }
}
