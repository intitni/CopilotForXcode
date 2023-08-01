import Foundation
import SwiftUI

#if canImport(LicenseManagement)

import LicenseManagement

#else

public typealias PlusFeatureFlag = Int

public struct PlusFeatureFlags {
    public let browserTab = 1
    public let unlimitedCustomCommands = 1
    init() {}
}

#endif

public func withFeatureEnabled(
    _ flag: KeyPath<PlusFeatureFlags, PlusFeatureFlag>,
    then: () throws -> Void
) rethrows {
    #if canImport(LicenseManagement)
    try LicenseManagement.withFeatureEnabled(flag, then: then)
    #endif
}

public func withFeatureEnabled(
    _ flag: KeyPath<PlusFeatureFlags, PlusFeatureFlag>,
    then: () async throws -> Void
) async rethrows {
    #if canImport(LicenseManagement)
    try await LicenseManagement.withFeatureEnabled(flag, then: then)
    #endif
}

public func isFeatureAvailable(_ flag: KeyPath<PlusFeatureFlags, PlusFeatureFlag>) -> Bool {
    #if canImport(LicenseManagement)
    return LicenseManagement.isFeatureAvailable(flag)
    #else
    return false
    #endif
}

