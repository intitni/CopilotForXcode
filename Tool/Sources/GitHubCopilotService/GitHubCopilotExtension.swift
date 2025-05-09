import BuiltinExtension
import CopilotForXcodeKit
import Foundation
import LanguageServerProtocol
import Logger
import Preferences
import Workspace

public final class GitHubCopilotExtension: BuiltinExtension {
    public var extensionIdentifier: String { "com.github.copilot" }

    public let suggestionService: GitHubCopilotSuggestionService
    public let chatService: GitHubCopilotChatService

    private var extensionUsage = ExtensionUsage(
        isSuggestionServiceInUse: false,
        isChatServiceInUse: false
    )
    private var isLanguageServerInUse: Bool {
        extensionUsage.isSuggestionServiceInUse || extensionUsage.isChatServiceInUse
    }

    let workspacePool: WorkspacePool

    let serviceLocator: ServiceLocatorType

    public init(workspacePool: WorkspacePool) {
        self.workspacePool = workspacePool
        serviceLocator = ServiceLocator(workspacePool: workspacePool)
        suggestionService = .init(serviceLocator: serviceLocator)
        chatService = .init(serviceLocator: serviceLocator)
    }

    public func workspaceDidOpen(_: WorkspaceInfo) {}

    public func workspaceDidClose(_: WorkspaceInfo) {}

    public func workspace(_ workspace: WorkspaceInfo, didOpenDocumentAt documentURL: URL) {
        guard isLanguageServerInUse else { return }
        // check if file size is larger than 15MB, if so, return immediately
        if let attrs = try? FileManager.default
            .attributesOfItem(atPath: documentURL.path),
            let fileSize = attrs[FileAttributeKey.size] as? UInt64,
            fileSize > 15 * 1024 * 1024
        { return }

        Task {
            do {
                let content = try String(contentsOf: documentURL, encoding: .utf8)
                guard let service = await serviceLocator.getService(from: workspace) else { return }
                try await service.notifyOpenTextDocument(fileURL: documentURL, content: content)
            } catch {
                Logger.gitHubCopilot.error(error.localizedDescription)
            }
        }
    }

    public func workspace(_ workspace: WorkspaceInfo, didSaveDocumentAt documentURL: URL) {
        guard isLanguageServerInUse else { return }
        Task {
            do {
                guard let service = await serviceLocator.getService(from: workspace) else { return }
                try await service.notifySaveTextDocument(fileURL: documentURL)
            } catch {
                Logger.gitHubCopilot.error(error.localizedDescription)
            }
        }
    }

    public func workspace(_ workspace: WorkspaceInfo, didCloseDocumentAt documentURL: URL) {
        guard isLanguageServerInUse else { return }
        Task {
            do {
                guard let service = await serviceLocator.getService(from: workspace) else { return }
                try await service.notifyCloseTextDocument(fileURL: documentURL)
            } catch {
                Logger.gitHubCopilot.error(error.localizedDescription)
            }
        }
    }

    public func workspace(
        _ workspace: WorkspaceInfo,
        didUpdateDocumentAt documentURL: URL,
        content: String?
    ) {
        guard isLanguageServerInUse else { return }
        // check if file size is larger than 15MB, if so, return immediately
        if let attrs = try? FileManager.default
            .attributesOfItem(atPath: documentURL.path),
            let fileSize = attrs[FileAttributeKey.size] as? UInt64,
            fileSize > 15 * 1024 * 1024
        { return }

        Task {
            guard let content else { return }
            guard let service = await serviceLocator.getService(from: workspace) else { return }
            do {
                try await service.notifyChangeTextDocument(
                    fileURL: documentURL,
                    content: content,
                    version: 0
                )
            } catch let error as ServerError {
                switch error {
                case .serverError(-32602, _, _): // parameter incorrect
                    Logger.gitHubCopilot.error(error.localizedDescription)
                    // Reopen document if it's not found in the language server
                    self.workspace(workspace, didOpenDocumentAt: documentURL)
                default:
                    Logger.gitHubCopilot.error(error.localizedDescription)
                }
            } catch {
                Logger.gitHubCopilot.error(error.localizedDescription)
            }
        }
    }

    public func extensionUsageDidChange(_ usage: ExtensionUsage) {
        extensionUsage = usage
        if !usage.isChatServiceInUse && !usage.isSuggestionServiceInUse {
            terminate()
        }
    }

    public func terminate() {
        for workspace in workspacePool.workspaces.values {
            guard let plugin = workspace.plugin(for: GitHubCopilotWorkspacePlugin.self)
            else { continue }
            plugin.terminate()
        }
    }
}

protocol ServiceLocatorType {
    func getService(from workspace: WorkspaceInfo) async -> GitHubCopilotService?
}

class ServiceLocator: ServiceLocatorType {
    let workspacePool: WorkspacePool

    init(workspacePool: WorkspacePool) {
        self.workspacePool = workspacePool
    }

    func getService(from workspace: WorkspaceInfo) async -> GitHubCopilotService? {
        guard let workspace = workspacePool.workspaces[workspace.workspaceURL],
              let plugin = workspace.plugin(for: GitHubCopilotWorkspacePlugin.self)
        else { return nil }
        return await plugin.gitHubCopilotService
    }
}

extension GitHubCopilotExtension {
    public struct Token: Codable {
//        let codesearch: Bool
        public let individual: Bool
        public let endpoints: Endpoints
        public let chat_enabled: Bool
//        public let sku: String
//        public  let copilotignore_enabled: Bool
//        public  let limited_user_quotas: String?
//        public let tracking_id: String
//        public  let xcode: Bool
//        public  let limited_user_reset_date: String?
//        public  let telemetry: String
//        public  let prompt_8k: Bool
        public let token: String
//        public  let nes_enabled: Bool
//        public  let vsc_electron_fetcher_v2: Bool
//        public  let code_review_enabled: Bool
//        public  let annotations_enabled: Bool
//        public  let chat_jetbrains_enabled: Bool
//        public  let xcode_chat: Bool
//        public  let refresh_in: Int
//        public  let snippy_load_test_enabled: Bool
//        public  let trigger_completion_after_accept: Bool
        public let expires_at: Int
//        public  let public_suggestions: String
//        public  let code_quote_enabled: Bool

        public struct Endpoints: Codable {
            public let api: String
            public let proxy: String
            public let telemetry: String
//            public let origin-tracker: String
        }
    }

    struct AuthInfo: Codable {
        public let user: String
        public let oauth_token: String
        public let githubAppId: String
    }

    static var authInfo: AuthInfo? {
        guard let urls = try? GitHubCopilotBaseService.createFoldersIfNeeded()
        else { return nil }
        let path = urls.supportURL
            .appendingPathComponent("undefined")
            .appendingPathComponent(".config")
            .appendingPathComponent("github-copilot")
            .appendingPathComponent("apps.json").path
        guard FileManager.default.fileExists(atPath: path) else { return nil }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let json = try JSONSerialization
                .jsonObject(with: data, options: []) as? [String: [String: String]]
            guard let firstEntry = json?.values.first else { return nil }
            let jsonData = try JSONSerialization.data(withJSONObject: firstEntry, options: [])
            return try JSONDecoder().decode(AuthInfo.self, from: jsonData)
        } catch {
            Logger.gitHubCopilot.error(error.localizedDescription)
            return nil
        }
    }

    @MainActor
    static var cachedToken: Token?

    public static func fetchToken() async throws -> Token {
        guard let authToken = authInfo?.oauth_token
        else { throw GitHubCopilotError.notLoggedIn }

        let oldToken = await MainActor.run { cachedToken }
        if let oldToken {
            let expiresAt = Date(timeIntervalSince1970: TimeInterval(oldToken.expires_at))
            if expiresAt > Date() {
                return oldToken
            }
        }

        let url = URL(string: "https://api.github.com/copilot_internal/v2/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("token \(authToken)", forHTTPHeaderField: "authorization")
        request.setValue("unknown-editor/0", forHTTPHeaderField: "editor-version")
        request.setValue("unknown-editor-plugin/0", forHTTPHeaderField: "editor-plugin-version")
        request.setValue("1.236.0", forHTTPHeaderField: "copilot-language-server-version")
        request.setValue("GithubCopilot/1.236.0", forHTTPHeaderField: "user-agent")
        request.setValue("*/*", forHTTPHeaderField: "accept")
        request.setValue("gzip,deflate,br", forHTTPHeaderField: "accept-encoding")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
            let newToken = try JSONDecoder().decode(Token.self, from: data)
            await MainActor.run { cachedToken = newToken }
            return newToken
        } catch {
            Logger.service.error(error.localizedDescription)
            throw error
        }
    }

    public static func fetchLLMModels() async throws -> [GitHubCopilotLLMModel] {
        let token = try await GitHubCopilotExtension.fetchToken()
        guard let endpoint = URL(string: token.endpoints.api + "/models") else {
            throw CancellationError()
        }
        var request = URLRequest(url: endpoint)
        request.setValue(
            "Copilot for Xcode/\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")",
            forHTTPHeaderField: "Editor-Version"
        )
        request.setValue("Bearer \(token.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("vscode-chat", forHTTPHeaderField: "Copilot-Integration-Id")
        request.setValue("2023-07-07", forHTTPHeaderField: "X-Github-Api-Version")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let response = response as? HTTPURLResponse else {
            throw CancellationError()
        }

        guard response.statusCode == 200 else {
            throw CancellationError()
        }

        struct Model: Decodable {
            struct Limit: Decodable {
                var max_context_window_tokens: Int
            }

            struct Capability: Decodable {
                var type: String?
                var family: String?
                var limit: Limit?
            }

            var id: String
            var capabilities: Capability
        }
        
        struct Body: Decodable {
            var data: [Model]
        }

        let models = try JSONDecoder().decode(Body.self, from: data)
            .data
            .filter {
                $0.capabilities.type == "chat"
            }
            .map {
                GitHubCopilotLLMModel(
                    modelId: $0.id,
                    familyName: $0.capabilities.family ?? "",
                    contextWindow: $0.capabilities.limit?.max_context_window_tokens ?? 0
                )
            }
        return models
    }
}

