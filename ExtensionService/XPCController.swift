import Foundation
import Logger
import XPCShared

final class XPCController: XPCServiceDelegate {
    let bridge: XPCCommunicationBridge
    let xpcListener: NSXPCListener
    let xpcServiceDelegate: ServiceDelegate

    var pingTask: Task<Void, Error>?

    init() {
        let bridge = XPCCommunicationBridge(logger: .client)
        let listener = NSXPCListener.anonymous()
        let delegate = ServiceDelegate()
        listener.delegate = delegate
        listener.resume()
        xpcListener = listener
        xpcServiceDelegate = delegate
        self.bridge = bridge

        Task {
            bridge.setDelegate(self)
            createPingTask()
        }
    }
    
    func quit() async {
        bridge.setDelegate(nil)
        pingTask?.cancel()
        #if DEBUG
        // Kickstart restarts the rebuilt bridge; quit() would exit(0) and hit launchd's 10s throttle.
        #else
        try? await bridge.quit()
        #endif
    }

    deinit {
        xpcListener.invalidate()
        pingTask?.cancel()
    }

    func createPingTask() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    try await self.bridge.updateServiceEndpoint(self.xpcListener.endpoint)
                    #if DEBUG
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    #else
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                    #endif
                } catch {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    #if DEBUG
                    // No log, but you should run CommunicationBridge, too.
                    #else
                    Logger.service
                        .error("Failed to connect to bridge: \(error.localizedDescription)")
                    #endif
                }
            }
        }
    }

    func connectionDidInvalidate() async {
        // ignore
    }

    func connectionDidInterrupt() async {
        createPingTask() // restart the ping task so that it can bring the bridge back immediately.
    }
}

