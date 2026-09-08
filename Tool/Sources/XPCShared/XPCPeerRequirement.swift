import Foundation
import ObjectiveCExceptionHandling

public enum XPCPeerRequirement {
    /// anchor apple generic and certificate leaf[subject.OU] = "<TEAMID>"
    public static func codeSigningRequirement(teamID: String) -> String {
        #"anchor apple generic and certificate leaf[subject.OU] = "\#(teamID)""#
    }

    /// `TEAM_ID_PREFIX` is `$(TeamIdentifierPrefix)` (e.g. `94G4SCKS9Z.`).
    public static func teamID(fromPrefix prefix: String?) -> String? {
        guard let prefix else { return nil }
        let teamID = prefix.hasSuffix(".") ? String(prefix.dropLast()) : prefix
        guard !teamID.isEmpty,
              teamID.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) })
        else { return nil }
        return teamID
    }

    /// Malformed requirement strings raise `NSException` rather than a Swift `Error`.
    public static func setCodeSigningRequirement(
        on connection: NSXPCConnection,
        teamID: String
    ) throws {
        try ObjcExceptionHandler.catchException {
            connection.setCodeSigningRequirement(codeSigningRequirement(teamID: teamID))
        }
    }
}
