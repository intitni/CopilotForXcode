import Foundation
import LanguageClient
import LanguageServerProtocol
import Logger
import Preferences
import SuggestionModel
import XPCShared

public protocol GitHubCopilotAuthServiceType {
    func checkStatus() async throws -> GitHubCopilotAccountStatus
    func signInInitiate() async throws -> (verificationUri: String, userCode: String)
    func signInConfirm(userCode: String) async throws
        -> (username: String, status: GitHubCopilotAccountStatus)
    func signOut() async throws -> GitHubCopilotAccountStatus
    func version() async throws -> String
}

public protocol GitHubCopilotSuggestionServiceType {
    func getCompletions(
        fileURL: URL,
        content: String,
        cursorPosition: CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        ignoreSpaceOnlySuggestions: Bool
    ) async throws -> [CodeSuggestion]
    func notifyAccepted(_ completion: CodeSuggestion) async
    func notifyRejected(_ completions: [CodeSuggestion]) async
    func notifyOpenTextDocument(fileURL: URL, content: String) async throws
    func notifyChangeTextDocument(fileURL: URL, content: String) async throws
    func notifyCloseTextDocument(fileURL: URL) async throws
    func notifySaveTextDocument(fileURL: URL) async throws
}

protocol GitHubCopilotLSP {
    func sendRequest<E: GitHubCopilotRequestType>(_ endpoint: E) async throws -> E.Response
    func sendNotification(_ notif: ClientNotification) async throws
}

enum GitHubCopilotError: Error, LocalizedError {
    case languageServerNotInstalled

    var errorDescription: String? {
        switch self {
        case .languageServerNotInstalled:
            return "Language server is not installed."
        }
    }
}

public class GitHubCopilotBaseService {
    let projectRootURL: URL
    var server: GitHubCopilotLSP
    var localProcessServer: CopilotLocalProcessServer?

    init(designatedServer: GitHubCopilotLSP) {
        projectRootURL = URL(fileURLWithPath: "/")
        server = designatedServer
    }

    init(projectRootURL: URL) throws {
        self.projectRootURL = projectRootURL
        let (server, localServer) = try {
            let urls = try GitHubCopilotBaseService.createFoldersIfNeeded()
            var userEnvPath = ProcessInfo.processInfo.userEnvironment["PATH"] ?? ""
            if userEnvPath.isEmpty {
                userEnvPath = "/usr/bin:/usr/local/bin" // fallback
            }
            let executionParams: Process.ExecutionParameters
            let runner = UserDefaults.shared.value(for: \.runNodeWith)

            let agentJSURL = urls.executableURL.appendingPathComponent("copilot/dist/agent.js")
            guard FileManager.default.fileExists(atPath: agentJSURL.path) else {
                throw GitHubCopilotError.languageServerNotInstalled
            }

            switch runner {
            case .bash:
                let nodePath = UserDefaults.shared.value(for: \.nodePath)
                let command = [
                    nodePath.isEmpty ? "node" : nodePath,
                    "\"\(agentJSURL.path)\"",
                    "--stdio",
                ].joined(separator: " ")
                executionParams = {
                    Process.ExecutionParameters(
                        path: "/bin/bash",
                        arguments: ["-i", "-l", "-c", command],
                        environment: [:],
                        currentDirectoryURL: urls.supportURL
                    )
                }()
            case .shell:
                let shell = ProcessInfo.processInfo.userEnvironment["SHELL"] ?? "/bin/bash"
                let nodePath = UserDefaults.shared.value(for: \.nodePath)
                let command = [
                    nodePath.isEmpty ? "node" : nodePath,
                    "\"\(agentJSURL.path)\"",
                    "--stdio",
                ].joined(separator: " ")
                executionParams = {
                    Process.ExecutionParameters(
                        path: shell,
                        arguments: ["-i", "-l", "-c", command],
                        environment: [:],
                        currentDirectoryURL: urls.supportURL
                    )
                }()
            case .env:
                executionParams = {
                    let nodePath = UserDefaults.shared.value(for: \.nodePath)
                    return Process.ExecutionParameters(
                        path: "/usr/bin/env",
                        arguments: [
                            nodePath.isEmpty ? "node" : nodePath,
                            agentJSURL.path,
                            "--stdio",
                        ],
                        environment: [
                            "PATH": userEnvPath,
                        ],
                        currentDirectoryURL: urls.supportURL
                    )
                }()
            }
            let localServer = CopilotLocalProcessServer(executionParameters: executionParams)
            
            localServer.logMessages = UserDefaults.shared.value(for: \.gitHubCopilotVerboseLog)
            localServer.notificationHandler = { _, respond in
                respond(.timeout)
            }
            let server = InitializingServer(server: localServer)

            server.initializeParamsProvider = {
                let capabilities = ClientCapabilities(
                    workspace: nil,
                    textDocument: nil,
                    window: nil,
                    general: nil,
                    experimental: nil
                )

                return InitializeParams(
                    processId: Int(ProcessInfo.processInfo.processIdentifier),
                    clientInfo: .init(
                        name: Bundle.main
                            .object(forInfoDictionaryKey: "HOST_APP_NAME") as? String
                            ?? "Copilot for Xcode"
                    ),
                    locale: nil,
                    rootPath: projectRootURL.path,
                    rootUri: projectRootURL.path,
                    initializationOptions: nil,
                    capabilities: capabilities,
                    trace: .off,
                    workspaceFolders: nil
                )
            }

            return (server, localServer)
        }()
        
        self.server = server
        self.localProcessServer = localServer
    }

    public static func createFoldersIfNeeded() throws -> (
        applicationSupportURL: URL,
        gitHubCopilotURL: URL,
        executableURL: URL,
        supportURL: URL
    ) {
        let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent(
            Bundle.main
                .object(forInfoDictionaryKey: "APPLICATION_SUPPORT_FOLDER") as! String
        )

        if !FileManager.default.fileExists(atPath: supportURL.path) {
            try? FileManager.default
                .createDirectory(at: supportURL, withIntermediateDirectories: false)
        }
        let gitHubCopilotFolderURL = supportURL.appendingPathComponent("GitHub Copilot")
        if !FileManager.default.fileExists(atPath: gitHubCopilotFolderURL.path) {
            try? FileManager.default
                .createDirectory(at: gitHubCopilotFolderURL, withIntermediateDirectories: false)
        }
        let supportFolderURL = gitHubCopilotFolderURL.appendingPathComponent("support")
        if !FileManager.default.fileExists(atPath: supportFolderURL.path) {
            try? FileManager.default
                .createDirectory(at: supportFolderURL, withIntermediateDirectories: false)
        }
        let executableFolderURL = gitHubCopilotFolderURL.appendingPathComponent("executable")
        if !FileManager.default.fileExists(atPath: executableFolderURL.path) {
            try? FileManager.default
                .createDirectory(at: executableFolderURL, withIntermediateDirectories: false)
        }
        
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executableFolderURL.path
        )
        
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: supportFolderURL.path
        )

        return (supportURL, gitHubCopilotFolderURL, executableFolderURL, supportFolderURL)
    }
}

public final class GitHubCopilotAuthService: GitHubCopilotBaseService,
    GitHubCopilotAuthServiceType
{
    public init() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        try super.init(projectRootURL: home)
        Task {
            try? await server.sendRequest(GitHubCopilotRequest.SetEditorInfo())
        }
    }

    public func checkStatus() async throws -> GitHubCopilotAccountStatus {
        try await server.sendRequest(GitHubCopilotRequest.CheckStatus()).status
    }

    public func signInInitiate() async throws -> (verificationUri: String, userCode: String) {
        let result = try await server.sendRequest(GitHubCopilotRequest.SignInInitiate())
        return (result.verificationUri, result.userCode)
    }

    public func signInConfirm(userCode: String) async throws
        -> (username: String, status: GitHubCopilotAccountStatus)
    {
        let result = try await server
            .sendRequest(GitHubCopilotRequest.SignInConfirm(userCode: userCode))
        return (result.user, result.status)
    }

    public func signOut() async throws -> GitHubCopilotAccountStatus {
        try await server.sendRequest(GitHubCopilotRequest.SignOut()).status
    }

    public func version() async throws -> String {
        try await server.sendRequest(GitHubCopilotRequest.GetVersion()).version
    }
}

public final class GitHubCopilotSuggestionService: GitHubCopilotBaseService,
    GitHubCopilotSuggestionServiceType
{
    private var ongoingTasks = Set<Task<[CodeSuggestion], Error>>()

    override public init(projectRootURL: URL = URL(fileURLWithPath: "/")) throws {
        try super.init(projectRootURL: projectRootURL)
    }

    override init(designatedServer: GitHubCopilotLSP) {
        super.init(designatedServer: designatedServer)
    }

    public func getCompletions(
        fileURL: URL,
        content: String,
        cursorPosition: CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        ignoreSpaceOnlySuggestions: Bool
    ) async throws -> [CodeSuggestion] {
        let languageId = languageIdentifierFromFileURL(fileURL)

        let relativePath = {
            let filePath = fileURL.path
            let rootPath = projectRootURL.path
            if let range = filePath.range(of: rootPath),
               range.lowerBound == filePath.startIndex
            {
                let relativePath = filePath.replacingCharacters(
                    in: filePath.startIndex..<range.upperBound,
                    with: ""
                )
                return relativePath
            }
            return filePath
        }()

        ongoingTasks.forEach { $0.cancel() }
        ongoingTasks.removeAll()
        await localProcessServer?.cancelOngoingTasks()

        let task = Task {
            let completions = try await server
                .sendRequest(GitHubCopilotRequest.GetCompletionsCycling(doc: .init(
                    source: content,
                    tabSize: tabSize,
                    indentSize: indentSize,
                    insertSpaces: !usesTabsForIndentation,
                    path: fileURL.path,
                    uri: fileURL.path,
                    relativePath: relativePath,
                    languageId: languageId,
                    position: cursorPosition
                )))
                .completions
                .filter { completion in
                    if ignoreSpaceOnlySuggestions {
                        return !completion.text.allSatisfy { $0.isWhitespace || $0.isNewline }
                    }
                    return true
                }
            try Task.checkCancellation()
            return completions
        }

        ongoingTasks.insert(task)

        return try await task.value
    }

    public func notifyAccepted(_ completion: CodeSuggestion) async {
        _ = try? await server.sendRequest(
            GitHubCopilotRequest.NotifyAccepted(completionUUID: completion.uuid)
        )
    }

    public func notifyRejected(_ completions: [CodeSuggestion]) async {
        _ = try? await server.sendRequest(
            GitHubCopilotRequest.NotifyRejected(completionUUIDs: completions.map(\.uuid))
        )
    }

    public func notifyOpenTextDocument(
        fileURL: URL,
        content: String
    ) async throws {
        let languageId = languageIdentifierFromFileURL(fileURL)
        let uri = "file://\(fileURL.path)"
//        Logger.service.debug("Open \(uri), \(content.count)")
        try await server.sendNotification(
            .didOpenTextDocument(
                DidOpenTextDocumentParams(
                    textDocument: .init(
                        uri: uri,
                        languageId: languageId.rawValue,
                        version: 0,
                        text: content
                    )
                )
            )
        )
    }

    public func notifyChangeTextDocument(fileURL: URL, content: String) async throws {
        let uri = "file://\(fileURL.path)"
//        Logger.service.debug("Change \(uri), \(content.count)")
        try await server.sendNotification(
            .didChangeTextDocument(
                DidChangeTextDocumentParams(
                    uri: uri,
                    version: 0,
                    contentChange: .init(
                        range: nil,
                        rangeLength: nil,
                        text: content
                    )
                )
            )
        )
    }

    public func notifySaveTextDocument(fileURL: URL) async throws {
        let uri = "file://\(fileURL.path)"
//        Logger.service.debug("Save \(uri)")
        try await server.sendNotification(.didSaveTextDocument(.init(uri: uri)))
    }

    public func notifyCloseTextDocument(fileURL: URL) async throws {
        let uri = "file://\(fileURL.path)"
//        Logger.service.debug("Close \(uri)")
        try await server.sendNotification(.didCloseTextDocument(.init(uri: uri)))
    }
}

extension InitializingServer: GitHubCopilotLSP {
    func sendRequest<E: GitHubCopilotRequestType>(_ endpoint: E) async throws -> E.Response {
        try await sendRequest(endpoint.request)
    }
}

