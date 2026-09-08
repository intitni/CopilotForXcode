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
    #else
    try then()
    #endif
}

public func withFeatureEnabled(
    _ flag: KeyPath<PlusFeatureFlags, PlusFeatureFlag>,
    then: () async throws -> Void
) async rethrows {
    #if canImport(LicenseManagement)
    try await LicenseManagement.withFeatureEnabled(flag, then: then)
    #else
    try await then()
    #endif
}

public func isFeatureAvailable(_ flag: KeyPath<PlusFeatureFlags, PlusFeatureFlag>) -> Bool {
    #if canImport(LicenseManagement)
    return LicenseManagement.isFeatureAvailable(flag)
    #else
    // Fork: this build ships no license package, so every Plus-gated limit is lifted instead of
    // being reported as locked. Features whose implementation lives in a closed-source module are
    // still guarded by `canImport` at their call site.
    return true
    #endif
}

