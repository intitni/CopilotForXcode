import Foundation

public enum GitHubCopilotAccountStatus: String, Codable, CustomStringConvertible {
    case alreadySignedIn = "AlreadySignedIn"
    case maybeOk = "MaybeOk"
    case notAuthorized = "NotAuthorized"
    case notSignedIn = "NotSignedIn"
    case ok = "OK"

    public var description: String {
        switch self {
        case .alreadySignedIn:
            return "Already Signed In"
        case .maybeOk:
            return "Maybe OK"
        case .notAuthorized:
            return "Not Authorized"
        case .notSignedIn:
            return "Not Signed In"
        case .ok:
            return "OK"
        }
    }
}
