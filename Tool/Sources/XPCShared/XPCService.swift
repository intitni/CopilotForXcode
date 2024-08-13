import Foundation
import Logger

@globalActor
public enum XPCServiceActor {
    public actor TheActor {}
    public static let shared = TheActor()
}

class XPCService {
    enum Kind {
        case machService(identifier: String)
        case anonymous(endpoint: NSXPCListenerEndpoint)
    }

    let kind: Kind
    let interface: NSXPCInterface
    let logger: Logger
    weak var delegate: XPCServiceDelegate?

    @XPCServiceActor
    private var isInvalidated = false

    @XPCServiceActor
    private lazy var _connection: InvalidatingConnection? = buildConnection()

    @XPCServiceActor
    var connection: NSXPCConnection? {
        if isInvalidated { _connection = nil }
        if _connection == nil { rebuildConnection() }
        return _connection?.connection
    }

    init(
        kind: Kind,
        interface: NSXPCInterface,
        logger: Logger,
        delegate: XPCServiceDelegate? = nil
    ) {
        self.kind = kind
        self.interface = interface
        self.logger = logger
        self.delegate = delegate
    }

    @XPCServiceActor
    private func buildConnection() -> InvalidatingConnection {
        logger.info("Rebuilding connection")
        let connection = switch kind {
        case let .machService(name):
            NSXPCConnection(machServiceName: name)
        case let .anonymous(endpoint):
            NSXPCConnection(listenerEndpoint: endpoint)
        }
        connection.remoteObjectInterface = interface
        connection.invalidationHandler = { [weak self] in
            self?.logger.info("XPCService Invalidated")
            Task { [weak self] in
                self?.markAsInvalidated()
                await self?.delegate?.connectionDidInvalidate()
            }
        }
        connection.interruptionHandler = { [weak self] in
            self?.logger.info("XPCService interrupted")
            Task { [weak self] in
                await self?.delegate?.connectionDidInterrupt()
            }
        }
        connection.resume()
        return .init(connection)
    }

    @XPCServiceActor
    private func markAsInvalidated() {
        isInvalidated = true
    }

    @XPCServiceActor
    private func rebuildConnection() {
        _connection = buildConnection()
    }
}

public protocol XPCServiceDelegate: AnyObject {
    func connectionDidInvalidate() async
    func connectionDidInterrupt() async
}

private class InvalidatingConnection {
    let connection: NSXPCConnection
    init(_ connection: NSXPCConnection) {
        self.connection = connection
    }

    deinit {
        connection.invalidationHandler = {}
        connection.interruptionHandler = {}
        connection.invalidate()
    }
}

struct NoDataError: Error {}

struct EmptyResponseError: Error, LocalizedError {
    var errorDescription: String? {
        "The server is not returning a response. The app may be installed in the wrong directory."
    }
}

struct AutoFinishContinuation<T> {
    var continuation: AsyncThrowingStream<T, Error>.Continuation

    func resume(_ value: T) {
        continuation.yield(value)
        continuation.finish()
    }

    func reject(_ error: Error) {
        if (error as NSError).code == -100 {
            continuation.finish(throwing: CancellationError())
        } else {
            continuation.finish(throwing: error)
        }
    }
}

@XPCServiceActor
func withXPCServiceConnected<T, P>(
    connection: NSXPCConnection,
    _ fn: @escaping (P, AutoFinishContinuation<T>) -> Void
) async throws -> T {
    let stream: AsyncThrowingStream<T, Error> = AsyncThrowingStream { continuation in
        let service = connection.remoteObjectProxyWithErrorHandler {
            continuation.finish(throwing: $0)
        } as! P
        fn(service, .init(continuation: continuation))
    }
    guard let result = try await stream.first(where: { _ in true }) else {
        throw EmptyResponseError()
    }
    return result
}

@XPCServiceActor
public func testXPCListenerEndpoint(_ endpoint: NSXPCListenerEndpoint) async -> Bool {
    let connection = NSXPCConnection(listenerEndpoint: endpoint)
    defer { connection.invalidate() }
    let stream: AsyncThrowingStream<Void, Error> = AsyncThrowingStream { continuation in
        _ = connection.remoteObjectProxyWithErrorHandler {
            continuation.finish(throwing: $0)
        }
        continuation.yield(())
        continuation.finish()
    }
    do {
        guard let _ = try await stream.first(where: { _ in true }) else {
            throw EmptyResponseError()
        }
        return true
    } catch {
        return false
    }
}

