import Foundation

@objc(CommunicationBridgeXPCServiceProtocol)
public protocol CommunicationBridgeXPCServiceProtocol {
    func launchExtensionServiceIfNeeded(withReply reply: @escaping (NSXPCListenerEndpoint?) -> Void)
    func quit(withReply reply: @escaping () -> Void)
    func updateServiceEndpoint(
        endpoint: NSXPCListenerEndpoint,
        withReply reply: @escaping () -> Void
    )
}

