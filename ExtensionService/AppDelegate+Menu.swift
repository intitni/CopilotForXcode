import AppKit
import Foundation
import Preferences
import XcodeInspector

extension AppDelegate {
    fileprivate var statusBarMenuIdentifier: NSUserInterfaceItemIdentifier {
        .init("statusBarMenu")
    }

    fileprivate var xcodeInspectorDebugMenuIdentifier: NSUserInterfaceItemIdentifier {
        .init("xcodeInspectorDebugMenu")
    }

    @objc func buildStatusBarMenu() {
        let statusBar = NSStatusBar.system
        statusBarItem = statusBar.statusItem(
            withLength: NSStatusItem.squareLength
        )
        statusBarItem.button?.image = NSImage(named: "MenuBarIcon")

        let statusBarMenu = NSMenu(title: "Status Bar Menu")
        statusBarMenu.identifier = statusBarMenuIdentifier
        statusBarItem.menu = statusBarMenu

        let hostAppName = Bundle.main.object(forInfoDictionaryKey: "HOST_APP_NAME") as? String
            ?? "Copilot for Xcode"

        let copilotName = NSMenuItem(
            title: hostAppName,
            action: nil,
            keyEquivalent: ""
        )

        let checkForUpdate = NSMenuItem(
            title: "Check for Updates",
            action: #selector(checkForUpdate),
            keyEquivalent: ""
        )

        let openCopilotForXcode = NSMenuItem(
            title: "Open \(hostAppName)",
            action: #selector(openCopilotForXcode),
            keyEquivalent: ""
        )

        let openGlobalChat = NSMenuItem(
            title: "Open Chat",
            action: #selector(openGlobalChat),
            keyEquivalent: ""
        )

        let xcodeInspectorDebug = NSMenuItem(
            title: "Xcode Inspector Debug",
            action: nil,
            keyEquivalent: ""
        )

        let xcodeInspectorDebugMenu = NSMenu(title: "Xcode Inspector Debug")
        xcodeInspectorDebugMenu.identifier = xcodeInspectorDebugMenuIdentifier
        xcodeInspectorDebug.submenu = xcodeInspectorDebugMenu
        xcodeInspectorDebug.isHidden = false

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: ""
        )
        quitItem.target = self

        statusBarMenu.addItem(copilotName)
        statusBarMenu.addItem(openCopilotForXcode)
        statusBarMenu.addItem(checkForUpdate)
        statusBarMenu.addItem(.separator())
        statusBarMenu.addItem(openGlobalChat)
        statusBarMenu.addItem(.separator())
        statusBarMenu.addItem(xcodeInspectorDebug)
        statusBarMenu.addItem(quitItem)

        statusBarMenu.delegate = self
        xcodeInspectorDebugMenu.delegate = self
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        switch menu.identifier {
        case statusBarMenuIdentifier:
            if let xcodeInspectorDebug = menu.items.first(where: { item in
                item.submenu?.identifier == xcodeInspectorDebugMenuIdentifier
            }) {
                xcodeInspectorDebug.isHidden = !UserDefaults.shared
                    .value(for: \.enableXcodeInspectorDebugMenu)
            }
        case xcodeInspectorDebugMenuIdentifier:
            let inspector = XcodeInspector.shared
            menu.items.removeAll()
            menu.items.append(.text("Active Project: \(inspector.activeProjectRootURL)"))
            menu.items.append(.text("Active Workspace: \(inspector.activeWorkspaceURL)"))
            menu.items.append(.text("Active Document: \(inspector.activeDocumentURL)"))
            for xcode in inspector.xcodes {
                let item = NSMenuItem(
                    title: "Xcode \(xcode.runningApplication.processIdentifier)",
                    action: nil,
                    keyEquivalent: ""
                )
                menu.addItem(item)
                let xcodeMenu = NSMenu()
                item.submenu = xcodeMenu
                xcodeMenu.items.append(.text("Is Active: \(xcode.isActive)"))
                xcodeMenu.items.append(.text("Active Project: \(xcode.projectRootURL)"))
                xcodeMenu.items.append(.text("Active Workspace: \(xcode.workspaceURL)"))
                xcodeMenu.items.append(.text("Active Document: \(xcode.documentURL)"))
                
                for (key, workspace) in xcode.realtimeWorkspaces {
                    let workspaceItem = NSMenuItem(
                        title: "Workspace \(key)",
                        action: nil,
                        keyEquivalent: ""
                    )
                    xcodeMenu.items.append(workspaceItem)
                    let workspaceMenu = NSMenu()
                    workspaceItem.submenu = workspaceMenu
                    let tabsItem = NSMenuItem(
                        title: "Tabs",
                        action: nil,
                        keyEquivalent: ""
                    )
                    workspaceMenu.addItem(tabsItem)
                    let tabsMenu = NSMenu()
                    tabsItem.submenu = tabsMenu
                    for tab in workspace.tabs {
                        tabsMenu.addItem(.text(tab))
                    }
                }
            }
        default:
            break
        }
    }
}

private extension NSMenuItem {
    static func text(_ text: String) -> NSMenuItem {
        let item = NSMenuItem(
            title: text,
            action: nil,
            keyEquivalent: ""
        )
        item.isEnabled = false
        return item
    }
}
