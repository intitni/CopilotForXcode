import AppKit
import Client
import CopilotModel
import SwiftUI

struct CopilotView: View {
    @Environment(\.openURL) var openURL
    @AppStorage("username") var username: String = ""
    @State var copilotStatus: CopilotStatus?
    @State var message: String?
    @State var userCode: String?
    @State var version: String?
    @State var isRunningAction: Bool = false
    @State var isUserCodeCopiedAlertPresented = false

    var body: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Copilot")
                        .font(.title)
                        .padding(.bottom, 12)
                    Text("Version: \(version ?? "Loading..")")
                    Text("Status: \(copilotStatus?.description ?? "Loading..")")
                    HStack(alignment: .center) {
                        Button("Refresh") { checkStatus() }
                        if copilotStatus == .notSignedIn {
                            Button("Sign In") { signIn() }
                                .alert(isPresented: $isUserCodeCopiedAlertPresented) {
                                    Alert(
                                        title: Text(userCode ?? ""),
                                        message: Text("The user code is pasted into your clipboard, please paste it in the opened website to login.\nAfter that, click \"Confirm Sign-in\" to finish."),
                                        dismissButton: .default(Text("OK"))
                                    )
                                }
                            Button("Confirm Sign-in") { confirmSignIn() }
                        }
                        if copilotStatus == .ok || copilotStatus == .alreadySignedIn || copilotStatus == .notAuthorized {
                            Button("Sign Out") { signOut() }
                        }
                        if isRunningAction {
                            ActivityIndicatorView()
                        }
                    }
                    .buttonStyle(.copilot)
                    .opacity(isRunningAction ? 0.8 : 1)
                    .disabled(isRunningAction)
                }
                Spacer()
            }.overlay(alignment: .topTrailing) {
                if let message {
                    Text(message)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.red)
                        )
                }
            }
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
                let service = try getService()
                copilotStatus = try await service.checkStatus()
                version = try await service.getVersion()
                message = nil
                isRunningAction = false
            } catch {
                message = error.localizedDescription
            }
        }
    }

    func signIn() {
        Task {
            isRunningAction = true
            defer { isRunningAction = false }
            do {
                let service = try getService()
                let (uri, userCode) = try await service.signInInitiate()
                self.userCode = userCode
                guard let url = URL(string: uri) else {
                    message = "Verification URI is incorrect."
                    return
                }
                let pasteboard = NSPasteboard.general
                pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
                pasteboard.setString(userCode, forType: NSPasteboard.PasteboardType.string)
                message = "Usercode \(userCode) already copied!"
                openURL(url)
                isUserCodeCopiedAlertPresented = true
            } catch {
                message = error.localizedDescription
            }
        }
    }

    func confirmSignIn() {
        Task {
            isRunningAction = true
            defer { isRunningAction = false }
            do {
                let service = try getService()
                guard let userCode else {
                    message = "Usercode is empty."
                    return
                }
                let (username, status) = try await service.signInConfirm(userCode: userCode)
                self.username = username
                copilotStatus = status
            } catch {
                message = error.localizedDescription
            }
        }
    }

    func signOut() {
        Task {
            isRunningAction = true
            defer { isRunningAction = false }
            do {
                let service = try getService()
                copilotStatus = try await service.signOut()
            } catch {
                message = error.localizedDescription
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
            CopilotView(copilotStatus: .notSignedIn, version: "1.0.0")

            CopilotView(copilotStatus: .alreadySignedIn, message: "Error")

            CopilotView(copilotStatus: .alreadySignedIn, isRunningAction: true)
        }
        .frame(height: 800)
        .padding(.all, 8)
        .background(Color.black)
    }
}
