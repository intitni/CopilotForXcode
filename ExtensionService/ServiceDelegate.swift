import Foundation
import Logger
import Service
import XPCShared

class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(
        _: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        guard let teamID = XPCPeerRequirement.teamID(fromPrefix: teamIDPrefix) else {
            Logger.service.error(
                "Rejected XPC connection from pid \(newConnection.processIdentifier): Team ID is unavailable."
            )
            return false
        }
        let requirement = XPCPeerRequirement.codeSigningRequirement(teamID: teamID)
        do {
            try XPCPeerRequirement.setCodeSigningRequirement(on: newConnection, teamID: teamID)
        } catch {
            Logger.service.error(
                "Rejected XPC connection from pid \(newConnection.processIdentifier): invalid code signing requirement (\(requirement))."
            )
            return false
        }

        newConnection.exportedInterface = NSXPCInterface(
            with: XPCServiceProtocol.self
        )

        let exportedObject = XPCService()
        newConnection.exportedObject = exportedObject
        newConnection.resume()
        return true
    }
}

