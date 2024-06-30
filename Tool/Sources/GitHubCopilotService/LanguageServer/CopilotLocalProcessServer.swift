import Foundation
import JSONRPC
import LanguageClient
import LanguageServerProtocol
import Logger
import ProcessEnv

/// A clone of the `LocalProcessServer`.
/// We need it because the original one does not allow us to handle custom notifications.
class CopilotLocalProcessServer {
    private let transport: StdioDataTransport
    private let customTransport: CustomDataTransport
    private let process: Process
    private var wrappedServer: CustomJSONRPCLanguageServer?
    var terminationHandler: (() -> Void)?
    @MainActor var ongoingCompletionRequestIDs: [JSONId] = []

    public convenience init(
        path: String,
        arguments: [String],
        environment: [String: String]? = nil,
        serverNotificationHandler: ServerNotificationHandler
    ) {
        let params = Process.ExecutionParameters(
            path: path,
            arguments: arguments,
            environment: environment
        )

        self.init(executionParameters: params, serverNotificationHandler: serverNotificationHandler)
    }

    init(
        executionParameters parameters: Process.ExecutionParameters,
        serverNotificationHandler: ServerNotificationHandler
    ) {
        transport = StdioDataTransport()
        let framing = SeperatedHTTPHeaderMessageFraming()
        let messageTransport = MessageTransport(
            dataTransport: transport,
            messageProtocol: framing
        )
        customTransport = CustomDataTransport(nextTransport: messageTransport)
        wrappedServer = CustomJSONRPCLanguageServer(
            dataTransport: customTransport,
            serverNotificationHandler: serverNotificationHandler
        )

        process = Process()

        // Because the implementation of LanguageClient is so closed,
        // we need to get the request IDs from a custom transport before the data
        // is written to the language server.
        customTransport.onWriteRequest = { [weak self] request in
            if request.method == "getCompletionsCycling"
                || request.method == "textDocument/inlineCompletion"
            {
                Task { @MainActor [weak self] in
                    self?.ongoingCompletionRequestIDs.append(request.id)
                }
            }
        }

        process.standardInput = transport.stdinPipe
        process.standardOutput = transport.stdoutPipe
        process.standardError = transport.stderrPipe

        process.parameters = parameters

        process.terminationHandler = { [unowned self] task in
            self.processTerminated(task)
        }

        process.launch()
    }

    deinit {
        process.terminationHandler = nil
        process.terminate()
        transport.close()
    }

    private func processTerminated(_: Process) {
        transport.close()

        // releasing the server here will short-circuit any pending requests,
        // which might otherwise take a while to time out, if ever.
        wrappedServer = nil
        terminationHandler?()
    }

    var logMessages: Bool {
        get { return wrappedServer?.logMessages ?? false }
        set { wrappedServer?.logMessages = newValue }
    }

    func terminate() {
        process.terminate()
    }
}

extension CopilotLocalProcessServer: LanguageServerProtocol.Server {
    public var requestHandler: RequestHandler? {
        get { return wrappedServer?.requestHandler }
        set { wrappedServer?.requestHandler = newValue }
    }

    @available(*, deprecated, message: "Use `ServerNotificationHandler` instead")
    public var notificationHandler: NotificationHandler? {
        get { wrappedServer?.notificationHandler }
        set { wrappedServer?.notificationHandler = newValue }
    }

    public func sendNotification(
        _ notif: ClientNotification,
        completionHandler: @escaping (ServerError?) -> Void
    ) {
        guard let server = wrappedServer, process.isRunning else {
            completionHandler(.serverUnavailable)
            return
        }

        server.sendNotification(notif, completionHandler: completionHandler)
    }

    /// Cancel ongoing completion requests.
    public func cancelOngoingTasks() async {
        guard let server = wrappedServer, process.isRunning else {
            return
        }

        let task = Task { @MainActor in
            for id in self.ongoingCompletionRequestIDs {
                switch id {
                case let .numericId(id):
                    try? await server.sendNotification(.protocolCancelRequest(.init(id: id)))
                case let .stringId(id):
                    try? await server.sendNotification(.protocolCancelRequest(.init(id: id)))
                }
            }
            self.ongoingCompletionRequestIDs = []
        }

        await task.value
    }

    public func sendRequest<Response: Codable>(
        _ request: ClientRequest,
        completionHandler: @escaping (ServerResult<Response>) -> Void
    ) {
        guard let server = wrappedServer, process.isRunning else {
            completionHandler(.failure(.serverUnavailable))
            return
        }

        server.sendRequest(request, completionHandler: completionHandler)
    }
}

final class CustomJSONRPCLanguageServer: Server {
    let internalServer: JSONRPCLanguageServer

    typealias ProtocolResponse<T: Codable> = ProtocolTransport.ResponseResult<T>

    private let protocolTransport: ProtocolTransport

    var requestHandler: RequestHandler?
    var serverNotificationHandler: ServerNotificationHandler

    @available(*, deprecated, message: "Use `serverNotificationHandler` instead.")
    var notificationHandler: NotificationHandler? {
        get { nil }
        set {}
    }

    private var outOfBandError: Error?

    init(
        protocolTransport: ProtocolTransport,
        serverNotificationHandler: ServerNotificationHandler
    ) {
        self.serverNotificationHandler = serverNotificationHandler
        self.protocolTransport = protocolTransport
        internalServer = JSONRPCLanguageServer(protocolTransport: protocolTransport)

        let previousRequestHandler = protocolTransport.requestHandler

        protocolTransport.requestHandler = { [weak self] in
            guard let self else { return }
            if !self.handleRequest($0, data: $1, callback: $2) {
                previousRequestHandler?($0, $1, $2)
            }
        }
        protocolTransport.notificationHandler = { [weak self] in
            guard let self else { return }
            self.handleNotification($0, data: $1, block: $2)
        }
    }

    convenience init(
        dataTransport: DataTransport,
        serverNotificationHandler: ServerNotificationHandler
    ) {
        self.init(
            protocolTransport: ProtocolTransport(dataTransport: dataTransport),
            serverNotificationHandler: serverNotificationHandler
        )
    }

    deinit {
        protocolTransport.requestHandler = nil
        protocolTransport.notificationHandler = nil
    }

    var logMessages: Bool {
        get { return internalServer.logMessages }
        set { internalServer.logMessages = newValue }
    }
}

extension CustomJSONRPCLanguageServer {
    private func handleNotification(
        _ anyNotification: AnyJSONRPCNotification,
        data: Data,
        block: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                try await serverNotificationHandler.handleNotification(
                    anyNotification,
                    data: data
                )
                block(nil)
            } catch {
                block(error)
            }
        }
    }

    func sendNotification(
        _ notif: ClientNotification,
        completionHandler: @escaping (ServerError?) -> Void
    ) {
        internalServer.sendNotification(notif, completionHandler: completionHandler)
    }
}

extension CustomJSONRPCLanguageServer {
    private func handleRequest(
        _ request: AnyJSONRPCRequest,
        data: Data,
        callback: @escaping (AnyJSONRPCResponse) -> Void
    ) -> Bool {
        return false
    }
}

extension CustomJSONRPCLanguageServer {
    public func sendRequest<Response: Codable>(
        _ request: ClientRequest,
        completionHandler: @escaping (ServerResult<Response>) -> Void
    ) {
        internalServer.sendRequest(request, completionHandler: completionHandler)
    }
}

@GitHubCopilotSuggestionActor
final class ServerNotificationHandler {
    typealias Handler = (
        _ anyNotification: AnyJSONRPCNotification,
        _ data: Data
    ) async throws -> Bool

    var handlers = [AnyHashable: Handler]()
    nonisolated init() {}

    func handleNotification(
        _ anyNotification: AnyJSONRPCNotification,
        data: Data
    ) async throws {
        for handler in handlers.values {
            do {
                let handled = try await handler(anyNotification, data)
                if handled {
                    return
                }
            } catch {
                throw ServerError.notificationDispatchFailed(error)
            }
        }

        let methodName = anyNotification.method
        let debugDescription = {
            if let params = anyNotification.params {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                if let jsonData = try? encoder.encode(params),
                   let text = String(data: jsonData, encoding: .utf8)
                {
                    return text
                }
            }
            return "N/A"
        }()
        switch methodName {
        case "window/logMessage":
            if UserDefaults.shared.value(for: \.gitHubCopilotVerboseLog) {
                Logger.gitHubCopilot
                    .info("\(anyNotification.method): \(debugDescription)")
            }
        case "LogMessage":
            if UserDefaults.shared.value(for: \.gitHubCopilotVerboseLog) {
                Logger.gitHubCopilot
                    .info("\(anyNotification.method): \(debugDescription)")
            }
        case "statusNotification":
            if UserDefaults.shared.value(for: \.gitHubCopilotVerboseLog) {
                Logger.gitHubCopilot
                    .info("\(anyNotification.method): \(debugDescription)")
            }
        case "featureFlagsNotification":
            if UserDefaults.shared.value(for: \.gitHubCopilotVerboseLog) {
                Logger.gitHubCopilot
                    .info("\(anyNotification.method): \(debugDescription)")
            }
        case "conversation/preconditionsNotification":
            if UserDefaults.shared.value(for: \.gitHubCopilotVerboseLog) {
                Logger.gitHubCopilot
                    .info("\(anyNotification.method): \(debugDescription)")
            }
        default:
            throw ServerError.handlerUnavailable(methodName)
        }
    }
}

