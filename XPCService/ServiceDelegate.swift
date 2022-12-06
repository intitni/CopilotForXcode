import Foundation

class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(
        _ listener: NSXPCListener,
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
