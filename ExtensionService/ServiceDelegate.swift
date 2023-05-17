import Foundation
import Service
import XPCShared

class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(
        _: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(
            with: XPCServiceProtocol.self
        )

        let exportedObject = XPCService()
        newConnection.exportedObject = exportedObject
        newConnection.resume()
        return true
    }
}

