import Foundation
import XPCShared
import os.log

var asyncService: AsyncXPCService?
var shared = XPCService()

public func getService() throws -> AsyncXPCService {
    if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
        struct RunningInPreview: Error {}
        throw RunningInPreview()
    }
    if shared.isInvalidated {
        shared = XPCService()
        asyncService = nil
    }
    if let asyncService { return asyncService }
    let service = AsyncXPCService(connection: shared.connection)
    asyncService = service
    return service
}

class XPCService {
    var isInvalidated = false

    lazy var connection: NSXPCConnection = {
        let connection = NSXPCConnection(
            machServiceName: Bundle(for: XPCService.self)
                .object(forInfoDictionaryKey: "BUNDLE_IDENTIFIER_BASE") as! String + ".XPCService"
        )
        connection.remoteObjectInterface =
            NSXPCInterface(with: XPCServiceProtocol.self)
        connection.invalidationHandler = { [weak self] in
            os_log(.info, "XPCService Invalidated")
            self?.isInvalidated = true
        }
        connection.interruptionHandler = { [weak self] in
            os_log(.info, "XPCService interrupted")
        }
        connection.resume()
        return connection
    }()

    deinit {
        connection.invalidate()
    }
}
