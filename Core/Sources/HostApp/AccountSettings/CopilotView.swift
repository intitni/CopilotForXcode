import AppKit
import Client
import GitHubCopilotService
import Preferences
import SuggestionModel
import SwiftUI

struct CopilotView: View {
    static var copilotAuthService: GitHubCopilotAuthServiceType?
    
    class Settings: ObservableObject {
        @AppStorage(\.nodePath) var nodePath: String
        @AppStorage(\.runNodeWith) var runNodeWith
        @AppStorage("username") var username: String = ""

        init() {}
    }

    @Environment(\.openURL) var openURL
    @Environment(\.toast) var toast
    @StateObject var settings = Settings()

    @State var status: GitHubCopilotAccountStatus?
    @State var userCode: String?
    @State var version: String?
    @State var isRunningAction: Bool = false
    @State var isUserCodeCopiedAlertPresented = false
    
    func getGitHubCopilotAuthService() throws -> GitHubCopilotAuthServiceType {
        if let service = Self.copilotAuthService { return service }
        let service = try GitHubCopilotAuthService()
        Self.copilotAuthService = service
        return service
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Form {
                    TextField(text: $settings.nodePath, prompt: Text("node")) {
                        Text("Path to Node")
                    }

                    Picker(selection: $settings.runNodeWith) {
                        ForEach(NodeRunner.allCases, id: \.rawValue) { runner in
                            switch runner {
                            case .env:
                                Text("/usr/bin/env").tag(runner)
                            case .bash:
                                Text("/bin/bash -i -l").tag(runner)
                            case .shell:
                                Text("$SHELL -i -l").tag(runner)
                            }
                        }
                    } label: {
                        Text("Run Node with")
                    }

                    VStack { // workaround a layout issue of SwiftUI
                        Text(
                            "You may have to restart the helper app to apply the changes. To do so, simply close the helper app by clicking on the menu bar icon that looks like a steer wheel, it will automatically restart as needed."
                        )
                        .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading) {
                    Text("Language Server Version: \(version ?? "Loading..")")
                    Text("Status: \(status?.description ?? "Loading..")")

                    HStack(alignment: .center) {
                        Button("Refresh") { checkStatus() }
                        if status == .notSignedIn {
                            Button("Sign In") { signIn() }
                                .alert(isPresented: $isUserCodeCopiedAlertPresented) {
                                    Alert(
                                        title: Text(userCode ?? ""),
                                        message: Text(
                                            "The user code is pasted into your clipboard, please paste it in the opened website to login.\nAfter that, click \"Confirm Sign-in\" to finish."
                                        ),
                                        dismissButton: .default(Text("OK"))
                                    )
                                }
                            Button("Confirm Sign-in") { confirmSignIn() }
                        }
                        if status == .ok || status == .alreadySignedIn ||
                            status == .notAuthorized
                        {
                            Button("Sign Out") { signOut() }
                        }
                        if isRunningAction {
                            ActivityIndicatorView()
                        }
                    }
                    .opacity(isRunningAction ? 0.8 : 1)
                    .disabled(isRunningAction)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), style: .init(lineWidth: 1))
                }
            }
            Spacer()
        }.onAppear {
            if isPreview { return }
            checkStatus()
        }
    }

    func checkStatus() {
        Task {
            isRunningAction = true
            defer { isRunningAction = false }
            do {
                let service = try getGitHubCopilotAuthService()
                status = try await service.checkStatus()
                version = try await service.version()
                isRunningAction = false

                if status != .ok && status != .notSignedIn {
                    toast(
                        Text(
                            "GitHub Copilot status is not \"ok\". Please check if you have a valid GitHub Copilot subscription."
                        ),
                        .error
                    )
                }
            } catch {
                toast(Text(error.localizedDescription), .error)
            }
        }
    }

    func signIn() {
        Task {
            isRunningAction = true
            defer { isRunningAction = false }
            do {
                let service = try getGitHubCopilotAuthService()
                let (uri, userCode) = try await service.signInInitiate()
                self.userCode = userCode
                guard let url = URL(string: uri) else {
                    toast(Text("Verification URI is incorrect."), .error)
                    return
                }
                let pasteboard = NSPasteboard.general
                pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
                pasteboard.setString(userCode, forType: NSPasteboard.PasteboardType.string)
                toast(Text("Usercode \(userCode) already copied!"), .info)
                openURL(url)
                isUserCodeCopiedAlertPresented = true
            } catch {
                toast(Text(error.localizedDescription), .error)
            }
        }
    }

    func confirmSignIn() {
        Task {
            isRunningAction = true
            defer { isRunningAction = false }
            do {
                let service = try getGitHubCopilotAuthService()
                guard let userCode else {
                    toast(Text("Usercode is empty."), .error)
                    return
                }
                let (username, status) = try await service.signInConfirm(userCode: userCode)
                self.settings.username = username
                self.status = status
            } catch {
                toast(Text(error.localizedDescription), .error)
            }
        }
    }

    func signOut() {
        Task {
            isRunningAction = true
            defer { isRunningAction = false }
            do {
                let service = try getGitHubCopilotAuthService()
                status = try await service.signOut()
            } catch {
                toast(Text(error.localizedDescription), .error)
            }
        }
    }
}

struct ActivityIndicatorView: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSProgressIndicator {
        let progressIndicator = NSProgressIndicator()
        progressIndicator.style = .spinning
        progressIndicator.appearance = NSAppearance(named: .vibrantLight)
        progressIndicator.controlSize = .small
        progressIndicator.startAnimation(nil)
        return progressIndicator
    }

    func updateNSView(_: NSProgressIndicator, context _: Context) {
        // No-op
    }
}

struct CopilotView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 8) {
            CopilotView(status: .notSignedIn, version: "1.0.0")
            CopilotView(status: .alreadySignedIn, isRunningAction: true)
        }
        .padding(.all, 8)
    }
}

