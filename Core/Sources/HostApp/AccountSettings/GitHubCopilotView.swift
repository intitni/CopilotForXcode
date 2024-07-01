import AppKit
import Client
import GitHubCopilotService
import Preferences
import SharedUIComponents
import SuggestionBasic
import SwiftUI

struct GitHubCopilotView: View {
    static var copilotAuthService: GitHubCopilotAuthServiceType?

    class Settings: ObservableObject {
        @AppStorage(\.nodePath) var nodePath: String
        @AppStorage(\.runNodeWith) var runNodeWith
        @AppStorage("username") var username: String = ""
        @AppStorage(\.gitHubCopilotVerboseLog) var gitHubCopilotVerboseLog
        @AppStorage(\.gitHubCopilotProxyHost) var gitHubCopilotProxyHost
        @AppStorage(\.gitHubCopilotProxyPort) var gitHubCopilotProxyPort
        @AppStorage(\.gitHubCopilotProxyUsername) var gitHubCopilotProxyUsername
        @AppStorage(\.gitHubCopilotProxyPassword) var gitHubCopilotProxyPassword
        @AppStorage(\.gitHubCopilotUseStrictSSL) var gitHubCopilotUseStrictSSL
        @AppStorage(\.gitHubCopilotEnterpriseURI) var gitHubCopilotEnterpriseURI
        @AppStorage(\.gitHubCopilotPretendIDEToBeVSCode) var pretendIDEToBeVSCode
        @AppStorage(\.disableGitHubCopilotSettingsAutoRefreshOnAppear)
        var disableGitHubCopilotSettingsAutoRefreshOnAppear
        @AppStorage(\.gitHubCopilotLoadKeyChainCertificates)
        var gitHubCopilotLoadKeyChainCertificates
        init() {}
    }

    class ViewModel: ObservableObject {
        let installationManager = GitHubCopilotInstallationManager()

        @Published var installationStatus: GitHubCopilotInstallationManager.InstallationStatus?
        @Published var installationStep: GitHubCopilotInstallationManager.InstallationStep?

        init() {}

        init(
            installationStatus: GitHubCopilotInstallationManager.InstallationStatus,
            installationStep: GitHubCopilotInstallationManager.InstallationStep?
        ) {
            assert(isPreview)
            self.installationStatus = installationStatus
            self.installationStep = installationStep
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
                Task { @MainActor in
                    GitHubCopilotView.copilotAuthService = nil
                }
            }
        }
    }

    @Environment(\.openURL) var openURL
    @Environment(\.toast) var toast
    @StateObject var settings = Settings()
    @StateObject var viewModel = ViewModel()

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

    var installButton: some View {
        Button(action: {
            Task {
                do {
                    try await viewModel.install()
                } catch {
                    toast(error.localizedDescription, .error)
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
                    toast(error.localizedDescription, .error)
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
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                SubSection(
                    title: Text("Node Settings"),
                    description: """
                    You may have to restart the extension app to apply the changes. To do so, simply close the helper app by clicking on the menu bar icon that looks like a tentacle, it will automatically restart as needed.
                    """
                ) {
                    Form {
                        TextField(
                            text: $settings.nodePath,
                            prompt: Text(
                                "node"
                            )
                        ) {
                            Text("Path to Node (v18+)")
                        }

                        Text(
                            "Provide the path to the executable if it can't be found by the app, shim executable is not supported"
                        )
                        .lineLimit(10)
                        .foregroundColor(.secondary)
                        .font(.callout)
                        .dynamicHeightTextInFormWorkaround()

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

                        Group {
                            switch settings.runNodeWith {
                            case .env:
                                Text(
                                    "PATH: `/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin`"
                                )
                            case .bash:
                                Text("PATH inherited from bash configurations.")
                            case .shell:
                                Text("PATH inherited from $SHELL configurations.")
                            }
                        }
                        .lineLimit(10)
                        .foregroundColor(.secondary)
                        .font(.callout)
                        .dynamicHeightTextInFormWorkaround()
                        
                        Toggle(isOn: $settings.gitHubCopilotLoadKeyChainCertificates) {
                            Text("Load certificates in keychain")
                        }
                    }
                }

                SubSection(
                    title: Text("GitHub Copilot Language Server")
                ) {
                    HStack {
                        switch viewModel.installationStatus {
                        case .none:
                            Text("Copilot.Vim Version: Loading..")
                        case .notInstalled:
                            Text("Copilot.Vim Version: Not Installed")
                            installButton
                        case let .installed(version):
                            Text("Copilot.Vim Version: \(version)")
                            uninstallButton
                        case let .outdated(version, latest, _):
                            Text("Copilot.Vim Version: \(version) (Update Available: \(latest))")
                            updateButton
                            uninstallButton
                        case let .unsupported(version, latest):
                            Text("Copilot.Vim Version: \(version) (Supported Version: \(latest))")
                            updateButton
                            uninstallButton
                        }
                    }

                    Text("Language Server Version: \(version ?? "Loading..")")

                    Text("Status: \(status?.description ?? "Loading..")")

                    HStack(alignment: .center) {
                        Button("Refresh") {
                            viewModel.refreshInstallationStatus()
                            checkStatus()
                        }
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

                    Button("Refresh configurations") {
                        refreshConfiguration()
                    }
                }

                SettingsDivider("Advanced")

                Form {
                    Toggle("Verbose log", isOn: $settings.gitHubCopilotVerboseLog)
                    Toggle("Pretend IDE to be VSCode", isOn: $settings.pretendIDEToBeVSCode)
                }

                SettingsDivider("Enterprise")

                Form {
                    TextField(
                        text: $settings.gitHubCopilotEnterpriseURI,
                        prompt: Text("Leave it blank if non is available.")
                    ) {
                        Text("Auth provider URL")
                    }
                }

                SettingsDivider("Proxy")

                Form {
                    TextField(
                        text: $settings.gitHubCopilotProxyHost,
                        prompt: Text("xxx.xxx.xxx.xxx, leave it blank to disable proxy.")
                    ) {
                        Text("Proxy host")
                    }
                    TextField(text: $settings.gitHubCopilotProxyPort, prompt: Text("80")) {
                        Text("Proxy port")
                    }
                    TextField(text: $settings.gitHubCopilotProxyUsername) {
                        Text("Proxy username")
                    }
                    SecureField(text: $settings.gitHubCopilotProxyPassword) {
                        Text("Proxy password")
                    }
                    Toggle("Proxy strict SSL", isOn: $settings.gitHubCopilotUseStrictSSL)
                }
            }
            Spacer()
        }.onAppear {
            if isPreview { return }
            if settings.disableGitHubCopilotSettingsAutoRefreshOnAppear { return }
            viewModel.refreshInstallationStatus()
            checkStatus()
        }.onChange(of: settings.runNodeWith) { _ in
            Self.copilotAuthService = nil
        }.onChange(of: settings.nodePath) { _ in
            Self.copilotAuthService = nil
        }.onChange(of: viewModel.installationStep) { newValue in
            if let step = newValue {
                switch step {
                case .downloading:
                    toast("Downloading..", .info)
                case .uninstalling:
                    toast("Uninstalling old version..", .info)
                case .decompressing:
                    toast("Decompressing..", .info)
                case .done:
                    toast("Done!", .info)
                    checkStatus()
                }
            }
        }
        .textFieldStyle(.roundedBorder)
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

                if status != .ok, status != .notSignedIn {
                    toast(
                        "GitHub Copilot status is not \"ok\". Please check if you have a valid GitHub Copilot subscription.",

                        .error
                    )
                }
            } catch {
                toast(error.localizedDescription, .error)
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
                    toast("Verification URI is incorrect.", .error)
                    return
                }
                let pasteboard = NSPasteboard.general
                pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
                pasteboard.setString(userCode, forType: NSPasteboard.PasteboardType.string)
                toast("Usercode \(userCode) already copied!", .info)
                openURL(url)
                isUserCodeCopiedAlertPresented = true
            } catch {
                toast(error.localizedDescription, .error)
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
                    toast("Usercode is empty.", .error)
                    return
                }
                let (username, status) = try await service.signInConfirm(userCode: userCode)
                self.settings.username = username
                self.status = status
            } catch {
                toast(error.localizedDescription, .error)
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
                toast(error.localizedDescription, .error)
            }
        }
    }

    func refreshConfiguration() {
        NotificationCenter.default.post(
            name: .gitHubCopilotShouldRefreshEditorInformation,
            object: nil
        )

        Task {
            let service = try getService()
            do {
                try await service.postNotification(
                    name: Notification.Name
                        .gitHubCopilotShouldRefreshEditorInformation.rawValue
                )
            } catch {
                toast(error.localizedDescription, .error)
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
            GitHubCopilotView(status: .notSignedIn, version: "1.0.0")
            GitHubCopilotView(status: .alreadySignedIn, isRunningAction: true)
        }
        .padding(.all, 8)
    }
}

