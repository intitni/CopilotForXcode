import Foundation
import SwiftUI

#if canImport(LicenseManagement)

import LicenseManagement

#else

public typealias PlusFeatureFlag = Int

@dynamicMemberLookup
public struct PlusFeatureFlags {
    public subscript(dynamicMember dynamicMember: String) -> PlusFeatureFlag { return 0 }
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

