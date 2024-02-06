import Foundation

private var teamIDPrefix: String {
    Bundle.main.infoDictionary?["TEAM_ID_PREFIX"] as? String ?? ""
}

private var bundleIdentifierBase: String {
    Bundle.main.infoDictionary?["BUNDLE_IDENTIFIER_BASE"] as? String ?? ""
}

public var userDefaultSuiteName: String {
    "\(teamIDPrefix)group.\(bundleIdentifierBase)"
}

public var keychainAccessGroup: String {
    return "\(teamIDPrefix)\(bundleIdentifierBase).Shared"
}

public var keychainService: String {
    return bundleIdentifierBase
}

