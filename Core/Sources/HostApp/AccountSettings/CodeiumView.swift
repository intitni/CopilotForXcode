import CodeiumService
import Foundation
import SwiftUI

struct CodeiumView: View {
    class ViewModel: ObservableObject {
        let codeiumAuthService = CodeiumAuthService()
        let installationManager = CodeiumInstallationManager()
        @Published var isSignedIn: Bool
        @Published var installationStatus: CodeiumInstallationManager.InstallationStatus
        @Published var installationStep: CodeiumInstallationManager.InstallationStep?

        init() {
            isSignedIn = codeiumAuthService.isSignedIn
            installationStatus = installationManager.checkInstallation()
        }

        init(
            isSignedIn: Bool,
            installationStatus: CodeiumInstallationManager.InstallationStatus,
            installationStep: CodeiumInstallationManager.InstallationStep?
        ) {
            assert(isPreview)
            self.isSignedIn = isSignedIn
            self.installationStatus = installationStatus
            self.installationStep = installationStep
        }

        func generateAuthURL() -> URL {
            return URL(
                string: "https://www.codeium.com/profile?response_type=token&redirect_uri=show-auth-token&state=\(UUID().uuidString)&scope=openid%20profile%20email&redirect_parameters_type=query"
            )!
        }

        func signIn(token: String) async throws {
            try await codeiumAuthService.signIn(token: token)
            Task { @MainActor in isSignedIn = true }
        }

        func signOut() async throws {
            try await codeiumAuthService.signOut()
            Task { @MainActor in isSignedIn = false }
        }

        func refreshInstallationStatus() {
            Task { @MainActor in
                installationStatus = installationManager.checkInstallation()
            }
        }

        func install() async throws {
            defer { refreshInstallationStatus() }
            do {
                for try await step in installationManager.installLatestVersion() {
                    Task { @MainActor in
                        self.installationStep = step
                    }
                }
                Task {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    Task { @MainActor in
                        self.installationStep = nil
                    }
                }
            } catch {
                Task { @MainActor in
                    installationStep = nil
                }
                throw error
            }
        }

        func uninstall() {
            Task {
                defer { refreshInstallationStatus() }
                try await installationManager.uninstall()
            }
        }
    }

    @StateObject var viewModel = ViewModel()
    @Environment(\.toast) var toast
    @State var isSignInPanelPresented = false

    var installButton: some View {
        Button(action: {
            Task {
                do {
                    try await viewModel.install()
                } catch {
                    toast(Text(error.localizedDescription), .error)
                }
            }
        }) {
            Text("Install")
        }
        .disabled(viewModel.installationStep != nil)
    }

    var updateButton: some View {
        Button(action: {
            Task {
                do {
                    try await viewModel.install()
                } catch {
                    toast(Text(error.localizedDescription), .error)
                }
            }
        }) {
            Text("Update")
        }
        .disabled(viewModel.installationStep != nil)
    }

    var uninstallButton: some View {
        Button(action: {
            viewModel.uninstall()
        }) {
            Text("Uninstall")
        }
        .disabled(viewModel.installationStep != nil)
    }

    var body: some View {
        VStack(alignment: .leading) {
            switch viewModel.installationStatus {
            case .notInstalled:
                HStack {
                    Text("Language Server Version: Not Installed")
                    installButton
                }
            case let .installed(version):
                HStack {
                    Text("Language Server Version: \(version)")
                    uninstallButton
                }
            case let .outdated(current: current, latest: latest):
                HStack {
                    Text("Language Server Version: \(current) (Update Available: \(latest))")
                    uninstallButton
                    updateButton
                }
            case let .unsupported(current: current, latest: latest):
                HStack {
                    Text("Language Server Version: \(current) (Supported Version: \(latest))")
                    uninstallButton
                    updateButton
                }
            }

            if viewModel.isSignedIn {
                Text("Status: Signed In")

                Button(action: {
                    viewModel.isSignedIn = false
                }) {
                    Text("Sign Out")
                }

                Text(
                    "The key is stored in the keychain. The helper app may request permission to access the key, please click \"Always Allow\" to grant this access."
                )
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(.secondary)
            } else {
                Text("Status: Not Signed In")

                Button(action: {
                    isSignInPanelPresented = true
                }) {
                    Text("Sign In")
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), style: .init(lineWidth: 1))
        }
        .sheet(isPresented: $isSignInPanelPresented) {
            CodeiumSignInView(viewModel: viewModel, isPresented: $isSignInPanelPresented)
        }
        .onChange(of: viewModel.installationStep) { newValue in
            if let step = newValue {
                switch step {
                case .downloading:
                    toast(Text("Downloading.."), .info)
                case .uninstalling:
                    toast(Text("Uninstalling old version.."), .info)
                case .decompressing:
                    toast(Text("Decompressing.."), .info)
                case .done:
                    toast(Text("Done!"), .info)
                }
            }
        }
    }
}

struct CodeiumSignInView: View {
    let viewModel: CodeiumView.ViewModel
    @Binding var isPresented: Bool
    @Environment(\.openURL) var openURL
    @Environment(\.toast) var toast
    @State var isGeneratingKey = false
    @State var token = ""

    var body: some View {
        VStack {
            Text(
                "You will be redirected to codeium.com. Please paste the generated token below and click the \"Sign In\" button."
            )

            TextEditor(text: $token)
                .font(Font.system(.body, design: .monospaced))
                .padding(4)
                .frame(minHeight: 120)
                .multilineTextAlignment(.leading)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )

            Button(action: {
                isGeneratingKey = true
                Task {
                    do {
                        try await viewModel.signIn(token: token)
                        isGeneratingKey = false
                        isPresented = false
                    } catch {
                        isGeneratingKey = false
                        toast(Text(error.localizedDescription), .error)
                    }
                }
            }) {
                Text(isGeneratingKey ? "Signing In.." : "Sign In")
            }.disabled(isGeneratingKey)
        }
        .padding()
        .onAppear {
            openURL(viewModel.generateAuthURL())
        }
    }
}

struct CodeiumView_Previews: PreviewProvider {
    class TestViewModel: CodeiumView.ViewModel {
        override func generateAuthURL() -> URL {
            return URL(string: "about:blank")!
        }

        override func signIn(token: String) async throws {}

        override func signOut() async throws {}

        override func refreshInstallationStatus() {}

        override func install() async throws {}

        override func uninstall() {}
    }

    static var previews: some View {
        VStack(alignment: .leading, spacing: 8) {
            CodeiumView(viewModel: TestViewModel(
                isSignedIn: false,
                installationStatus: .notInstalled,
                installationStep: nil
            ))

            CodeiumView(viewModel: TestViewModel(
                isSignedIn: true,
                installationStatus: .installed("1.2.9"),
                installationStep: nil
            ))

            CodeiumView(viewModel: TestViewModel(
                isSignedIn: true,
                installationStatus: .outdated(current: "1.2.9", latest: "1.3.0"),
                installationStep: .downloading
            ))

            CodeiumView(viewModel: TestViewModel(
                isSignedIn: true,
                installationStatus: .unsupported(current: "1.5.9", latest: "1.3.0"),
                installationStep: .downloading
            ))
        }
        .padding(8)
    }
}

