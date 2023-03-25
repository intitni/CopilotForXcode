import Sparkle
import Logger

public final class UpdateChecker {
    let updater: SPUUpdater
    let hostBundleFound: Bool

    public init(hostBundle: Bundle?) {
        if hostBundle == nil {
            hostBundleFound = false
            Logger.updateChecker.error("Host bundle not found")
        } else {
            hostBundleFound = true
        }
        updater = SPUUpdater(
            hostBundle: hostBundle ?? Bundle.main,
            applicationBundle: Bundle.main,
            userDriver: SPUStandardUserDriver(hostBundle: hostBundle ?? Bundle.main, delegate: nil),
            delegate: nil
        )
        do {
            try updater.start()
        } catch {
            Logger.updateChecker.error(error.localizedDescription)
        }
    }

    public func checkForUpdates() {
        updater.checkForUpdates()
    }

    public var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }
}

