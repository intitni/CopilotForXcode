import Foundation
import Logger
import XPCShared

class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(
        _: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(
            with: CommunicationBridgeXPCServiceProtocol.self
        )

        let exportedObject = XPCService()
        newConnection.exportedObject = exportedObject
        newConnection.resume()
        
        Logger.temp.debug("Accepted new connection.")
        
        return true
    }
}

class XPCService: CommunicationBridgeXPCServiceProtocol {
    static var endpoint: NSXPCListenerEndpoint?

    func launchExtensionServiceIfNeeded(
        withReply reply: @escaping (NSXPCListenerEndpoint?) -> Void
    ) {
        #if DEBUG
        reply(Self.endpoint)
        #else
        // launch the app
        reply(endpoint)
        #endif
    }

    func quit(withReply reply: () -> Void) {
        listener.invalidate()
        exit(0)
    }

    func updateServiceEndpoint(endpoint: NSXPCListenerEndpoint, withReply reply: () -> Void) {
        Self.endpoint = endpoint
        reply()
    }
}

