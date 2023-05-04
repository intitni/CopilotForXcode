import Foundation
import Preferences

extension UserDefaultPreferenceKeys {
    struct OldMigrationVersion: UserDefaultPreferenceKey {
        typealias PreferenceValueType = String
        static let key = "OldMigrationVersion"
    }
    
    var oldMigrationVersion: OldMigrationVersion { .init() }
}

struct ServiceUpdateMigrator {
    func migrate() {
        migrate(
            from: UserDefaults.shared.value(for: \.oldMigrationVersion),
            to: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")
        )
    }
    
    func migrate(from oldVersion: String, to currentVersion: String) {
        guard let old = Int(oldVersion), let new = Int(currentVersion) else { return }
        guard old != new else { return }
        if old <= 135 {
            migrateFromLowerThanOrEqualToVersion135()
        }
    }
}

func migrateFromLowerThanOrEqualToVersion135() {}
