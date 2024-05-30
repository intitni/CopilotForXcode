import Logger
import Preferences
import Sparkle

public final class UpdateChecker {
    let updater: SPUUpdater
    let hostBundleFound: Bool
    let delegate: UpdaterDelegate
    public weak var updateCheckerDelegate: UpdateCheckerDelegate? {
        get { delegate.updateCheckerDelegate }
        set { delegate.updateCheckerDelegate = newValue }
    }

    public init(
        hostBundle: Bundle?,
        shouldAutomaticallyCheckForUpdate: Bool
    ) {
        if hostBundle == nil {
            hostBundleFound = false
            Logger.updateChecker.error("Host bundle not found")
        } else {
            hostBundleFound = true
        }
        delegate = .init(
            shouldAutomaticallyCheckForUpdate: shouldAutomaticallyCheckForUpdate
        )
        updater = SPUUpdater(
            hostBundle: hostBundle ?? Bundle.main,
            applicationBundle: Bundle.main,
            userDriver: SPUStandardUserDriver(hostBundle: hostBundle ?? Bundle.main, delegate: nil),
            delegate: delegate
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
    
    public func resetUpdateCycle() {
        updater.resetUpdateCycleAfterShortDelay()
    }

    public var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }
}

public protocol UpdateCheckerDelegate: AnyObject {
    func prepareForRelaunch(finish: @escaping () -> Void)
}

class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    let shouldAutomaticallyCheckForUpdate: Bool
    weak var updateCheckerDelegate: UpdateCheckerDelegate?

    init(shouldAutomaticallyCheckForUpdate: Bool) {
        self.shouldAutomaticallyCheckForUpdate = shouldAutomaticallyCheckForUpdate
    }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        // Not sure how it works
//        if !shouldAutomaticallyCheckForUpdate, updateCheck == .updatesInBackground {
//            throw CancellationError()
//        }
    }

    func updater(
        _ updater: SPUUpdater,
        shouldPostponeRelaunchForUpdate item: SUAppcastItem,
        untilInvokingBlock installHandler: @escaping () -> Void
    ) -> Bool {
        if let updateCheckerDelegate {
            updateCheckerDelegate.prepareForRelaunch(finish: installHandler)
            return true
        }
        return false
    }
    
    func updater(_ updater: SPUUpdater, willScheduleUpdateCheckAfterDelay delay: TimeInterval) {
        Logger.updateChecker.info("Will schedule update check after delay: \(delay)")
    }
    
    func updaterWillNotScheduleUpdateCheck(_ updater: SPUUpdater) {
        Logger.updateChecker.info("Will not schedule update check")
    }

    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        if UserDefaults.shared.value(for: \.installBetaBuilds) {
            Set(["beta"])
        } else {
            []
        }
    }
}

