import AppKit
import enum CopilotForXcodeKit.SuggestionServiceError
import Foundation
import LanguageClient
import LanguageServerProtocol
import Logger
import Preferences
import SuggestionBasic

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
        originalContent: String,
        cursorPosition: CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool
    ) async throws -> [CodeSuggestion]
    func notifyAccepted(_ completion: CodeSuggestion) async
    func notifyRejected(_ completions: [CodeSuggestion]) async
    func notifyOpenTextDocument(fileURL: URL, content: String) async throws
    func notifyChangeTextDocument(fileURL: URL, content: String, version: Int) async throws
    func notifyCloseTextDocument(fileURL: URL) async throws
    func notifySaveTextDocument(fileURL: URL) async throws
    func cancelRequest() async
    func terminate() async
}

protocol GitHubCopilotLSP {
    func sendRequest<E: GitHubCopilotRequestType>(
        _ endpoint: E,
        timeout: TimeInterval?
    ) async throws -> E.Response
    func sendNotification(_ notif: ClientNotification) async throws
}

extension GitHubCopilotLSP {
    func sendRequest<E: GitHubCopilotRequestType>(_ endpoint: E) async throws -> E.Response {
        try await sendRequest(endpoint, timeout: nil)
    }
}

enum GitHubCopilotError: Error, LocalizedError {
    case languageServerNotInstalled
    case languageServerError(ServerError)
    case failedToInstallStartScript
    case chatEndsWithError(String)

    var errorDescription: String? {
        switch self {
        case .languageServerNotInstalled:
            return "Language server is not installed."
        case .failedToInstallStartScript:
            return "Failed to install start script."
        case let .chatEndsWithError(errorMessage):
            return "Chat ended with error message: \(errorMessage)"
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
    let notificationHandler: ServerNotificationHandler

    deinit {
        localProcessServer?.terminate()
    }

    init(designatedServer: GitHubCopilotLSP) {
        projectRootURL = URL(fileURLWithPath: "/")
        server = designatedServer
        notificationHandler = .init()
    }

    init(projectRootURL: URL) throws {
        self.projectRootURL = projectRootURL
        let notificationHandler = ServerNotificationHandler()
        self.notificationHandler = notificationHandler
        let (server, localServer) = try { [notificationHandler] in
            let urls = try GitHubCopilotBaseService.createFoldersIfNeeded()
            let executionParams: Process.ExecutionParameters
            let runner = UserDefaults.shared.value(for: \.runNodeWith)

            guard let agentJSURL = { () -> URL? in
                let languageServerDotJS = urls.executableURL
                    .appendingPathComponent("copilot/dist/language-server.js")
                if FileManager.default.fileExists(atPath: languageServerDotJS.path) {
                    return languageServerDotJS
                }
                let agentsDotJS = urls.executableURL.appendingPathComponent("copilot/dist/agent.js")
                if FileManager.default.fileExists(atPath: agentsDotJS.path) {
                    return agentsDotJS
                }
                return nil
            }() else {
                throw GitHubCopilotError.languageServerNotInstalled
            }

            let indexJSURL: URL = try {
                if UserDefaults.shared.value(for: \.gitHubCopilotLoadKeyChainCertificates) {
                    let url = urls.executableURL
                        .appendingPathComponent("load-self-signed-cert-1.34.0.js")
                    if !FileManager.default.fileExists(atPath: url.path) {
                        let file = Bundle.module.url(
                            forResource: "load-self-signed-cert-1.34.0",
                            withExtension: "js"
                        )!
                        do {
                            try FileManager.default.copyItem(at: file, to: url)
                        } catch {
                            throw GitHubCopilotError.failedToInstallStartScript
                        }
                    }
                    return url
                } else {
                    return agentJSURL
                }
            }()

            switch runner {
            case .bash:
                let nodePath = UserDefaults.shared.value(for: \.nodePath)
                let command = [
                    nodePath.isEmpty ? "node" : nodePath,
                    "\"\(indexJSURL.path)\"",
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
                    "\"\(indexJSURL.path)\"",
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
                            indexJSURL.path,
                            "--stdio",
                        ],
                        environment: [
                            "PATH": userEnvPath,
                        ],
                        currentDirectoryURL: urls.supportURL
                    )
                }()
            }
            let localServer = CopilotLocalProcessServer(
                executionParameters: executionParams,
                serverNotificationHandler: notificationHandler
            )

            localServer.logMessages = UserDefaults.shared.value(for: \.gitHubCopilotVerboseLog)
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

        let notifications = NotificationCenter.default
            .notifications(named: .gitHubCopilotShouldRefreshEditorInformation)
        Task { [weak self] in
            _ = try? await server.sendRequest(GitHubCopilotRequest.SetEditorInfo())

            for await _ in notifications {
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

    func registerNotificationHandler(
        id: AnyHashable,
        _ block: @escaping ServerNotificationHandler.Handler
    ) {
        Task { @GitHubCopilotSuggestionActor in
            self.notificationHandler.handlers[id] = block
        }
    }

    func unregisterNotificationHandler(id: AnyHashable) {
        Task { @GitHubCopilotSuggestionActor in
            self.notificationHandler.handlers[id] = nil
        }
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

public final class GitHubCopilotService: GitHubCopilotBaseService,
    GitHubCopilotSuggestionServiceType
{
    private var ongoingTasks = Set<Task<[CodeSuggestion], Error>>()

    override public init(projectRootURL: URL = URL(fileURLWithPath: "/")) throws {
        try super.init(projectRootURL: projectRootURL)
    }

    override init(designatedServer: GitHubCopilotLSP) {
        super.init(designatedServer: designatedServer)
    }

    @GitHubCopilotSuggestionActor
    public func getCompletions(
        fileURL: URL,
        content: String,
        originalContent: String,
        cursorPosition: CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool
    ) async throws -> [CodeSuggestion] {
        ongoingTasks.forEach { $0.cancel() }
        ongoingTasks.removeAll()
        await localProcessServer?.cancelOngoingTasks()

        func sendRequest(maxTry: Int = 5) async throws -> [CodeSuggestion] {
            do {
                let completions = try await server
                    .sendRequest(GitHubCopilotRequest.InlineCompletion(doc: .init(
                        textDocument: .init(uri: fileURL.path, version: 1),
                        position: cursorPosition,
                        formattingOptions: .init(
                            tabSize: tabSize,
                            insertSpaces: !usesTabsForIndentation
                        ),
                        context: .init(triggerKind: .invoked)
                    )))
                    .items
                    .compactMap { (item: _) -> CodeSuggestion? in
                        guard let range = item.range else { return nil }
                        let suggestion = CodeSuggestion(
                            id: item.command?.arguments?.first ?? UUID().uuidString,
                            text: item.insertText,
                            position: cursorPosition,
                            range: .init(start: range.start, end: range.end)
                        )
                        return suggestion
                    }
                try Task.checkCancellation()
                return completions
            } catch let error as ServerError {
                switch error {
                case .serverError(1000, _, _): // not logged-in error
                    throw SuggestionServiceError
                        .notice(GitHubCopilotError.languageServerError(error))
                case .serverError:
                    // sometimes the content inside language server is not new enough, which can
                    // lead to an version mismatch error. We can try a few times until the content
                    // is up to date.
                    if maxTry <= 0 { break }
                    Logger.gitHubCopilot.error(
                        "Try getting suggestions again: \(GitHubCopilotError.languageServerError(error).localizedDescription)"
                    )
                    try await Task.sleep(nanoseconds: 200_000_000)
                    return try await sendRequest(maxTry: maxTry - 1)
                default:
                    break
                }
                throw GitHubCopilotError.languageServerError(error)
            } catch {
                throw error
            }
        }

        func recoverContent() async {
            try? await notifyChangeTextDocument(
                fileURL: fileURL,
                content: originalContent,
                version: 0
            )
        }

        // since when the language server is no longer using the passed in content to generate
        // suggestions, we will need to update the content to the file before we do any request.
        //
        // And sometimes the language server's content was not up to date and may generate
        // weird result when the cursor position exceeds the line.
        let task = Task { @GitHubCopilotSuggestionActor in
            try await notifyChangeTextDocument(
                fileURL: fileURL,
                content: content,
                version: 1
            )

            do {
                try Task.checkCancellation()
                return try await sendRequest()
            } catch let error as CancellationError {
                if ongoingTasks.isEmpty {
                    await recoverContent()
                }
                throw error
            } catch {
                await recoverContent()
                throw error
            }
        }

        ongoingTasks.insert(task)

        return try await task.value
    }

    @GitHubCopilotSuggestionActor
    public func cancelRequest() async {
        ongoingTasks.forEach { $0.cancel() }
        ongoingTasks.removeAll()
        await localProcessServer?.cancelOngoingTasks()
    }

    @GitHubCopilotSuggestionActor
    public func notifyAccepted(_ completion: CodeSuggestion) async {
        _ = try? await server.sendRequest(
            GitHubCopilotRequest.NotifyAccepted(completionUUID: completion.id)
        )
    }

    @GitHubCopilotSuggestionActor
    public func notifyRejected(_ completions: [CodeSuggestion]) async {
        _ = try? await server.sendRequest(
            GitHubCopilotRequest.NotifyRejected(completionUUIDs: completions.map(\.id))
        )
    }

    @GitHubCopilotSuggestionActor
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

    @GitHubCopilotSuggestionActor
    public func notifyChangeTextDocument(
        fileURL: URL,
        content: String,
        version: Int
    ) async throws {
        let uri = "file://\(fileURL.path)"
//        Logger.service.debug("Change \(uri), \(content.count)")
        try await server.sendNotification(
            .didChangeTextDocument(
                DidChangeTextDocumentParams(
                    uri: uri,
                    version: version,
                    contentChange: .init(
                        range: nil,
                        rangeLength: nil,
                        text: content
                    )
                )
            )
        )
    }

    @GitHubCopilotSuggestionActor
    public func notifySaveTextDocument(fileURL: URL) async throws {
        let uri = "file://\(fileURL.path)"
//        Logger.service.debug("Save \(uri)")
        try await server.sendNotification(.didSaveTextDocument(.init(uri: uri)))
    }

    @GitHubCopilotSuggestionActor
    public func notifyCloseTextDocument(fileURL: URL) async throws {
        let uri = "file://\(fileURL.path)"
//        Logger.service.debug("Close \(uri)")
        try await server.sendNotification(.didCloseTextDocument(.init(uri: uri)))
    }

    @GitHubCopilotSuggestionActor
    public func terminate() async {
        // automatically handled
    }
}

extension InitializingServer: GitHubCopilotLSP {
    func sendRequest<E: GitHubCopilotRequestType>(
        _ endpoint: E,
        timeout: TimeInterval? = nil
    ) async throws -> E.Response {
        if let timeout {
            return try await withCheckedThrowingContinuation { continuation in
                self.sendRequest(endpoint.request, timeout: timeout) { result in
                    continuation.resume(with: result)
                }
            }
        } else {
            return try await sendRequest(endpoint.request)
        }
    }
}

