import Foundation
import os.log
import XPCShared

let shared = XPCService()

public func getService() throws -> AsyncXPCService {
    if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
        struct RunningInPreview: Error {}
        throw RunningInPreview()
    }
    return AsyncXPCService(service: shared)
}

class XPCService {
    private var isInvalidated = false
    private lazy var _connection: NSXPCConnection = buildConnection()
    
    var connection: NSXPCConnection {
        if isInvalidated {
            _connection.invalidationHandler = {}
            _connection.interruptionHandler = {}
            isInvalidated = false
            _connection.invalidate()
            rebuildConnection()
        }
        return _connection
    }
    
    private func buildConnection() -> NSXPCConnection {
        let connection = NSXPCConnection(
            machServiceName: Bundle(for: XPCService.self)
                .object(forInfoDictionaryKey: "BUNDLE_IDENTIFIER_BASE") as! String + ".ExtensionService"
        )
        connection.remoteObjectInterface =
            NSXPCInterface(with: XPCServiceProtocol.self)
        connection.invalidationHandler = { [weak self] in
            os_log(.info, "XPCService Invalidated")
            self?.isInvalidated = true
        }
        connection.interruptionHandler = { [weak self] in
            os_log(.info, "XPCService interrupted")
            self?.isInvalidated = true
        }
        connection.resume()
        return connection
    }
    
    func rebuildConnection() {
        _connection = buildConnection()
    }

    deinit {
        _connection.invalidationHandler = {}
        _connection.interruptionHandler = {}
        _connection.invalidate()
    }
}
