import Configs
import Foundation
import Preferences

extension UserDefaultPreferenceKeys {
    struct OldMigrationVersion: UserDefaultPreferenceKey {
        var defaultValue: String = "0"
        let key = "OldMigrationVersion"
    }

    var oldMigrationVersion: OldMigrationVersion { .init() }
}

public struct ServiceUpdateMigrator {
    public init() {}

    public func migrate() async throws {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"

        try await migrate(from: UserDefaults.shared.value(for: \.oldMigrationVersion), to: version)
        UserDefaults.shared.set(version, for: \.oldMigrationVersion)
    }

    func migrate(from oldVersion: String, to currentVersion: String) async throws {
        guard let old = Int(oldVersion), old != 0 else { return }
        if old <= 135 {
            try migrateFromLowerThanOrEqualToVersion135()
        }
        if old < 240 {
            try migrateTo240()
        }
    }
}
