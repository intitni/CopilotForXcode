import AppKit
import FileChangeChecker
import LaunchAgentManager
import Logger
import Preferences
import Service
import ServiceManagement
import SwiftUI
import UpdateChecker
import UserNotifications

let bundleIdentifierBase = Bundle.main
    .object(forInfoDictionaryKey: "BUNDLE_IDENTIFIER_BASE") as! String
let serviceIdentifier = bundleIdentifierBase + ".ExtensionService"

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let scheduledCleaner = ScheduledCleaner()
    private let userDefaultsObserver = UserDefaultsObserver()
    private var statusBarItem: NSStatusItem!
    private var xpcListener: (NSXPCListener, ServiceDelegate)?
    private let updateChecker =
        UpdateChecker(
            hostBundle: locateHostBundleURL(url: Bundle.main.bundleURL)
                .flatMap(Bundle.init(url:))
        )

    func applicationDidFinishLaunching(_: Notification) {
        if ProcessInfo.processInfo.environment["IS_UNIT_TEST"] == "YES" { return }

        _ = GraphicalUserInterfaceController.shared
        _ = RealtimeSuggestionController.shared
        UserDefaults.setupDefaultSettings()
        setupQuitOnUpdate()
        setupQuitOnUserTerminated()
        xpcListener = setupXPCListener()
        Logger.service.info("XPC Service started.")
        NSApp.setActivationPolicy(.prohibited)
        buildStatusBarMenu()
    }

    @objc private func buildStatusBarMenu() {
        let statusBar = NSStatusBar.system
        statusBarItem = statusBar.statusItem(
            withLength: NSStatusItem.squareLength
        )
        statusBarItem.button?.image = NSImage(
            systemSymbolName: "steeringwheel",
            accessibilityDescription: nil
        )

        let statusBarMenu = NSMenu(title: "Status Bar Menu")
        statusBarItem.menu = statusBarMenu

        #if DEBUG
        let copilotName = NSMenuItem(
            title: "Copilot for Xcode - DEBUG",
            action: nil,
            keyEquivalent: ""
        )
        #else
        let copilotName = NSMenuItem(
            title: "Copilot for Xcode",
            action: nil,
            keyEquivalent: ""
        )
        #endif
        
        let checkForUpdate = NSMenuItem(
            title: "Check for Updates",
            action: #selector(checkForUpdate),
            keyEquivalent: ""
        )

        let toggleRealtimeSuggestions = NSMenuItem(
            title: "Real-time Suggestions",
            action: #selector(toggleRealtimeSuggestions),
            keyEquivalent: ""
        )
        toggleRealtimeSuggestions.state = UserDefaults.shared
            .value(for: \.realtimeSuggestionToggle) ? .on : .off
        toggleRealtimeSuggestions.target = self

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: ""
        )
        quitItem.target = self

        statusBarMenu.addItem(copilotName)
        statusBarMenu.addItem(checkForUpdate)
        statusBarMenu.addItem(.separator())
        statusBarMenu.addItem(toggleRealtimeSuggestions)
        statusBarMenu.addItem(.separator())
        statusBarMenu.addItem(quitItem)

        userDefaultsObserver.onChange = { key in
            switch key {
            case UserDefaultPreferenceKeys().realtimeSuggestionToggle.key:
                toggleRealtimeSuggestions.state = UserDefaults.shared
                    .value(for: \.realtimeSuggestionToggle) ? .on : .off
            default:
                break
            }
        }
    }

    @objc func quit() {
        exit(0)
    }

    @objc func toggleRealtimeSuggestions() {
        let isOn = !UserDefaults.shared.value(for: \.realtimeSuggestionToggle)
        if isOn {
            if !AXIsProcessTrusted() {
                let alert = NSAlert()
                let image = NSImage(
                    systemSymbolName: "exclamationmark.triangle.fill",
                    accessibilityDescription: nil
                )
                var config = NSImage.SymbolConfiguration(
                    textStyle: .body,
                    scale: .large
                )
                config = config.applying(.init(hierarchicalColor: .systemYellow))
                alert.icon = image?.withSymbolConfiguration(config)
                alert.messageText = "Accessibility API Permission Required"
                alert.informativeText =
                    "Permission not granted to use Accessibility API. Please turn in on in System Settings.app."
                alert.addButton(withTitle: "OK")
                alert.addButton(withTitle: "Cancel")
                alert.alertStyle = .warning
                alert.runModal()
                return
            }
        }
        UserDefaults.shared.set(isOn, for: \.realtimeSuggestionToggle)
    }

    func setupQuitOnUpdate() {
        Task {
            guard let url = Bundle.main.executableURL else { return }
            let checker = await FileChangeChecker(fileURL: url)

            // If Xcode or Copilot for Xcode is made active, check if the executable of this program
            // is changed. If changed, quit this program.

            let sequence = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didActivateApplicationNotification)
            for await notification in sequence {
                try Task.checkCancellation()
                guard let app = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                    app.isUserOfService
                else { continue }
                guard await checker.checkIfChanged() else {
                    Logger.service.info("Extension Service is not updated, no need to quit.")
                    continue
                }
                Logger.service.info("Extension Service will quit.")
                #if DEBUG
                #else
                exit(0)
                #endif
            }
        }
    }

    func setupQuitOnUserTerminated() {
        Task {
            // Whenever Xcode or the host application quits, check if any of the two is running.
            // If none, quit the XPC service.

            let sequence = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didTerminateApplicationNotification)
            for await notification in sequence {
                try Task.checkCancellation()
                guard UserDefaults.shared.value(for: \.quitXPCServiceOnXcodeAndAppQuit)
                else { continue }
                guard let app = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                    app.isUserOfService
                else { continue }
                if NSWorkspace.shared.runningApplications.contains(where: \.isUserOfService) {
                    continue
                }
                exit(0)
            }
        }
    }

    func setupXPCListener() -> (NSXPCListener, ServiceDelegate) {
        let listener = NSXPCListener(machServiceName: serviceIdentifier)
        let delegate = ServiceDelegate()
        listener.delegate = delegate
        listener.resume()
        return (listener, delegate)
    }

    func requestAccessoryAPIPermission() {
        AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true,
        ] as NSDictionary)
    }

    @objc func checkForUpdate() {
        updateChecker.checkForUpdates()
    }
}

private class UserDefaultsObserver: NSObject {
    var onChange: ((String?) -> Void)?

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        onChange?(keyPath)
    }

    override init() {
        super.init()
        observe(keyPath: UserDefaultPreferenceKeys().realtimeSuggestionToggle.key)
    }

    func observe(keyPath: String) {
        UserDefaults.shared.addObserver(self, forKeyPath: keyPath, options: .new, context: nil)
    }
}

extension NSRunningApplication {
    var isUserOfService: Bool {
        [
            "com.apple.dt.Xcode",
            bundleIdentifierBase,
        ].contains(bundleIdentifier)
    }
}

func locateHostBundleURL(url: URL) -> URL? {
    var nextURL = url
    while nextURL.path != "/" {
        nextURL = nextURL.deletingLastPathComponent()
        if nextURL.lastPathComponent.hasSuffix(".app") {
            return nextURL
        }
    }
    let devAppURL = url
        .deletingLastPathComponent()
        .appendingPathComponent("Copilot for Xcode Dev.app")
    return devAppURL
}
