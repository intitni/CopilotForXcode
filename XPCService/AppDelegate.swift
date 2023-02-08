import AppKit
import Service
import ServiceManagement
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
        AXIsProcessTrustedWithOptions(nil)
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
        let isOn = !UserDefaults.shared.bool(forKey: SettingsKey.realtimeSuggestionToggle)
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
        UserDefaults.shared.set(isOn, forKey: SettingsKey.realtimeSuggestionToggle)
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
