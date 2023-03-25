import SwiftUI

struct AppInfoView: View {
    @State var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    @Environment(\.updateChecker) var updateChecker

    var body: some View {
        Section {
            VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    Text("Copilot For Xcode")
                        .font(.title)
                    Text(appVersion ?? "")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.5))

                    Spacer()

                    Button(action: {
                        updateChecker.checkForUpdates()
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up.right.circle.fill")
                            Text("Check for Updates")
                        }
                    }
                    .buttonStyle(.copilot)
                }

                HStack(spacing: 16) {
                    Link(destination: URL(string: "https://github.com/intitni/CopilotForXcode")!) {
                        HStack(spacing: 2) {
                            Image(systemName: "link")
                            Text("GitHub")
                        }
                    }
                    .focusable(false)

                    Link(destination: URL(string: "https://www.buymeacoffee.com/intitni")!) {
                        HStack(spacing: 2) {
                            Image(systemName: "cup.and.saucer.fill")
                            Text("Buy Me A Coffee")
                        }
                    }
                    .focusable(false)
                }
            }
        }
    }
}

struct AppInfoView_Preview: PreviewProvider {
    static var previews: some View {
        AppInfoView()
            .background(.black)
    }
}
