import AppKit
import Service
import SwiftUI
import UserNotifications
import XPCShared

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let scheduledCleaner = ScheduledCleaner()
    private let userDefaultsObserver = UserDefaultsObserver()
    private var statusBarItem: NSStatusItem!

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
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

        let copilotName = NSMenuItem(
            title: "Copilot for Xcode",
            action: nil,
            keyEquivalent: ""
        )

        let toggleRealtimeSuggestions = NSMenuItem(
            title: "Real-time Suggestions",
            action: #selector(toggleRealtimeSuggestions),
            keyEquivalent: ""
        )
        toggleRealtimeSuggestions.state = UserDefaults.shared
            .bool(forKey: SettingsKey.realtimeSuggestionToggle) ? .on : .off
        toggleRealtimeSuggestions.target = self

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: ""
        )
        quitItem.target = self

        statusBarMenu.addItem(copilotName)
        statusBarMenu.addItem(.separator())
        statusBarMenu.addItem(toggleRealtimeSuggestions)
        statusBarMenu.addItem(.separator())
        statusBarMenu.addItem(quitItem)

        userDefaultsObserver.onChange = { key in
            switch key {
            case SettingsKey.realtimeSuggestionToggle:
                toggleRealtimeSuggestions.state = UserDefaults.shared
                    .bool(forKey: SettingsKey.realtimeSuggestionToggle) ? .on : .off
            default:
                break
            }
        }
        UserDefaults.shared.addObserver(
            userDefaultsObserver,
            forKeyPath: SettingsKey.realtimeSuggestionToggle,
            options: .new,
            context: nil
        )
    }

    @objc func quit() {
        exit(0)
    }

    @objc func toggleRealtimeSuggestions() {
        UserDefaults.shared.set(
            !UserDefaults.shared.bool(forKey: SettingsKey.realtimeSuggestionToggle),
            forKey: SettingsKey.realtimeSuggestionToggle
        )
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
}
