import AppKit
import Foundation
import LanguageClient
import LanguageServerProtocol
import Logger
import Preferences
import SuggestionModel

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
        ignoreSpaceOnlySuggestions: Bool,
        ignoreTrailingNewLinesAndSpaces: Bool
    ) async throws -> [CodeSuggestion]
    func notifyAccepted(_ completion: CodeSuggestion) async
    func notifyRejected(_ completions: [CodeSuggestion]) async
    func notifyOpenTextDocument(fileURL: URL, content: String) async throws
    func notifyChangeTextDocument(fileURL: URL, content: String) async throws
    func notifyCloseTextDocument(fileURL: URL) async throws
    func notifySaveTextDocument(fileURL: URL) async throws
    func cancelRequest() async
    func terminate() async
}

protocol GitHubCopilotLSP {
    func sendRequest<E: GitHubCopilotRequestType>(_ endpoint: E) async throws -> E.Response
    func sendNotification(_ notif: ClientNotification) async throws
}

enum GitHubCopilotError: Error, LocalizedError {
    case languageServerNotInstalled
    case languageServerError(ServerError)

    var errorDescription: String? {
        switch self {
        case .languageServerNotInstalled:
            return "Language server is not installed."
        case let .languageServerError(error):
            switch error {
            case let .handlerUnavailable(handler):
                return "Language server error: Handler \(handler) unavailable"
            case let .unhandledMethod(method):
                return "Language server error: Unhandled method \(method)"
            case let .notificationDispatchFailed(error):
                return "Language server error: Notification dispatch failed: \(error)"
            case let .requestDispatchFailed(error):
                return "Language server error: Request dispatch failed: \(error)"
            case let .clientDataUnavailable(error):
                return "Language server error: Client data unavailable: \(error)"
            case .serverUnavailable:
                return "Language server error: Server unavailable, please make sure that:\n1. The path to node is correctly set.\n2. The node is not a shim executable.\n3. the node version is high enough."
            case .missingExpectedParameter:
                return "Language server error: Missing expected parameter"
            case .missingExpectedResult:
                return "Language server error: Missing expected result"
            case let .unableToDecodeRequest(error):
                return "Language server error: Unable to decode request: \(error)"
            case let .unableToSendRequest(error):
                return "Language server error: Unable to send request: \(error)"
            case let .unableToSendNotification(error):
                return "Language server error: Unable to send notification: \(error)"
            case let .serverError(code: code, message: message, data: data):
                return "Language server error: Server error: \(code) \(message) \(String(describing: data))"
            case .invalidRequest:
                return "Language server error: Invalid request"
            case .timeout:
                return "Language server error: Timeout, please try again later"
            }
        }
    }
}

public extension Notification.Name {
    static let gitHubCopilotShouldRefreshEditorInformation = Notification
        .Name("com.intii.CopilotForXcode.GitHubCopilotShouldRefreshEditorInformation")
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
                executionParams = Process.ExecutionParameters(
                    path: "/bin/bash",
                    arguments: ["-i", "-l", "-c", command],
                    environment: [:],
                    currentDirectoryURL: urls.supportURL
                )
            case .shell:
                let shell = ProcessInfo.processInfo.shellExecutablePath
                let nodePath = UserDefaults.shared.value(for: \.nodePath)
                let command = [
                    nodePath.isEmpty ? "node" : nodePath,
                    "\"\(agentJSURL.path)\"",
                    "--stdio",
                ].joined(separator: " ")
                executionParams = Process.ExecutionParameters(
                    path: shell,
                    arguments: ["-i", "-l", "-c", command],
                    environment: [:],
                    currentDirectoryURL: urls.supportURL
                )
            case .env:
                let userEnvPath =
                    "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
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
        localProcessServer = localServer

        Task { [weak self] in
            _ = try? await server.sendRequest(GitHubCopilotRequest.SetEditorInfo())

            for await _ in NotificationCenter.default
                .notifications(named: .gitHubCopilotShouldRefreshEditorInformation)
            {
                print("Yes!")
                guard self != nil else { return }
                _ = try? await server.sendRequest(GitHubCopilotRequest.SetEditorInfo())
            }
        }
    }

    public static func createFoldersIfNeeded() throws -> (
        applicationSupportURL: URL,
        gitHubCopilotURL: URL,
        executableURL: URL,
        supportURL: URL
    ) {
        guard let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent(
            Bundle.main
                .object(forInfoDictionaryKey: "APPLICATION_SUPPORT_FOLDER") as! String
        ) else {
            throw CancellationError()
        }

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

        return (supportURL, gitHubCopilotFolderURL, executableFolderURL, supportFolderURL)
    }
}

public final class GitHubCopilotAuthService: GitHubCopilotBaseService,
    GitHubCopilotAuthServiceType
{
    public init() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        try super.init(projectRootURL: home)
    }

    public func checkStatus() async throws -> GitHubCopilotAccountStatus {
        do {
            return try await server.sendRequest(GitHubCopilotRequest.CheckStatus()).status
        } catch let error as ServerError {
            throw GitHubCopilotError.languageServerError(error)
        } catch {
            throw error
        }
    }

    public func signInInitiate() async throws -> (verificationUri: String, userCode: String) {
        do {
            let result = try await server.sendRequest(GitHubCopilotRequest.SignInInitiate())
            return (result.verificationUri, result.userCode)
        } catch let error as ServerError {
            throw GitHubCopilotError.languageServerError(error)
        } catch {
            throw error
        }
    }

    public func signInConfirm(userCode: String) async throws
        -> (username: String, status: GitHubCopilotAccountStatus)
    {
        do {
            let result = try await server
                .sendRequest(GitHubCopilotRequest.SignInConfirm(userCode: userCode))
            return (result.user, result.status)
        } catch let error as ServerError {
            throw GitHubCopilotError.languageServerError(error)
        } catch {
            throw error
        }
    }

    public func signOut() async throws -> GitHubCopilotAccountStatus {
        do {
            return try await server.sendRequest(GitHubCopilotRequest.SignOut()).status
        } catch let error as ServerError {
            throw GitHubCopilotError.languageServerError(error)
        } catch {
            throw error
        }
    }

    public func version() async throws -> String {
        do {
            return try await server.sendRequest(GitHubCopilotRequest.GetVersion()).version
        } catch let error as ServerError {
            throw GitHubCopilotError.languageServerError(error)
        } catch {
            throw error
        }
    }
}

@globalActor public enum GitHubCopilotSuggestionActor {
    public actor TheActor {}
    public static let shared = TheActor()
}

@GitHubCopilotSuggestionActor
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
        ignoreSpaceOnlySuggestions: Bool,
        ignoreTrailingNewLinesAndSpaces: Bool
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
                .map {
                    let suggestion = CodeSuggestion(
                        id: $0.uuid,
                        text: $0.text,
                        position: $0.position,
                        range: $0.range
                    )
                    if ignoreTrailingNewLinesAndSpaces {
                        var updated = suggestion
                        var text = updated.text[...]
                        while let last = text.last, last.isNewline || last.isWhitespace {
                            text = text.dropLast(1)
                        }
                        updated.text = String(text)
                        return updated
                    }
                    return suggestion
                }
            try Task.checkCancellation()
            return completions
        }

        ongoingTasks.insert(task)

        return try await task.value
    }

    public func cancelRequest() async {
        await localProcessServer?.cancelOngoingTasks()
    }

    public func notifyAccepted(_ completion: CodeSuggestion) async {
        _ = try? await server.sendRequest(
            GitHubCopilotRequest.NotifyAccepted(completionUUID: completion.id)
        )
    }

    public func notifyRejected(_ completions: [CodeSuggestion]) async {
        _ = try? await server.sendRequest(
            GitHubCopilotRequest.NotifyRejected(completionUUIDs: completions.map(\.id))
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

    public func terminate() async {
        // automatically handled
    }
}

extension InitializingServer: GitHubCopilotLSP {
    func sendRequest<E: GitHubCopilotRequestType>(_ endpoint: E) async throws -> E.Response {
        try await sendRequest(endpoint.request)
    }
}

