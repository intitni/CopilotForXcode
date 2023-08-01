import Dependencies
import Foundation
import SwiftUI

#if canImport(LicenseManagement)

import LicenseManagement

public func withFeatureEnabled(
    _ flag: KeyPath<PlusFeatureFlags, PlusFeatureFlag>,
    then: () throws -> Void
) rethrows {
    try LicenseManagement.withFeatureEnabled(flag, then: then)
}

public func withFeatureEnabled(
    _ flag: KeyPath<PlusFeatureFlags, PlusFeatureFlag>,
    then: () async throws -> Void
) async rethrows {
    try await LicenseManagement.withFeatureEnabled(flag, then: then)
}

public func isFeatureAvailable(_ flag: KeyPath<PlusFeatureFlags, PlusFeatureFlag>) -> Bool {
    LicenseManagement.isFeatureAvailable(flag)
}

#endif
