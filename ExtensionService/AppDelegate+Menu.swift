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

    fileprivate var accessibilityAPIPermissionMenuItemIdentifier: NSUserInterfaceItemIdentifier {
        .init("accessibilitAPIPermissionMenuItem")
    }

    fileprivate var sourceEditorDebugMenu: NSUserInterfaceItemIdentifier {
        .init("sourceEditorDebugMenu")
    }

    @MainActor
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

        let openExtensionManager = NSMenuItem(
            title: "Open Extension Manager",
            action: #selector(openExtensionManager),
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

        let accessibilityAPIPermission = NSMenuItem(
            title: "Accessibility API Permission: N/A",
            action: nil,
            keyEquivalent: ""
        )
        accessibilityAPIPermission.identifier = accessibilityAPIPermissionMenuItemIdentifier

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: ""
        )
        quitItem.target = self

        let reactivateObservationsItem = NSMenuItem(
            title: "Reactivate Observations to Xcode",
            action: #selector(reactivateObservationsToXcode),
            keyEquivalent: ""
        )

        reactivateObservationsItem.target = self

        statusBarMenu.addItem(copilotName)
        statusBarMenu.addItem(openCopilotForXcode)
        statusBarMenu.addItem(checkForUpdate)
        statusBarMenu.addItem(openExtensionManager)
        statusBarMenu.addItem(.separator())
        statusBarMenu.addItem(openGlobalChat)
        statusBarMenu.addItem(.separator())
        statusBarMenu.addItem(xcodeInspectorDebug)
        statusBarMenu.addItem(accessibilityAPIPermission)
        statusBarMenu.addItem(reactivateObservationsItem)
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

            if let accessibilityAPIPermission = menu.items.first(where: { item in
                item.identifier == accessibilityAPIPermissionMenuItemIdentifier
            }) {
                AXIsProcessTrusted()
                accessibilityAPIPermission.title =
                    "Accessibility API Permission: \(AXIsProcessTrusted() ? "Granted" : "Not Granted")"
            }

        case xcodeInspectorDebugMenuIdentifier:
            let inspector = XcodeInspector.shared
            menu.items.removeAll()
            menu.items
                .append(.text("Active Project: \(inspector.activeProjectRootURL?.path ?? "N/A")"))
            menu.items
                .append(.text("Active Workspace: \(inspector.activeWorkspaceURL?.path ?? "N/A")"))
            menu.items
                .append(.text("Active Document: \(inspector.activeDocumentURL?.path ?? "N/A")"))

            if let focusedWindow = inspector.focusedWindow {
                menu.items.append(.text(
                    "Active Window: \(focusedWindow.uiElement.identifier)"
                ))
            } else {
                menu.items.append(.text("Active Window: N/A"))
            }

            if let focusedElement = inspector.focusedElement {
                menu.items.append(.text(
                    "Focused Element: \(focusedElement.description)"
                ))
            } else {
                menu.items.append(.text("Focused Element: N/A"))
            }

            if let sourceEditor = inspector.focusedEditor {
                let label = sourceEditor.element.description
                menu.items
                    .append(.text("Active Source Editor: \(label.isEmpty ? "Unknown" : label)"))
            } else {
                menu.items.append(.text("Active Source Editor: N/A"))
            }

            menu.items.append(.separator())

            for xcode in inspector.xcodes {
                let item = NSMenuItem(
                    title: "Xcode \(xcode.processIdentifier)",
                    action: nil,
                    keyEquivalent: ""
                )
                menu.addItem(item)
                let xcodeMenu = NSMenu()
                item.submenu = xcodeMenu
                xcodeMenu.items.append(.text("Is Active: \(xcode.isActive)"))
                xcodeMenu.items
                    .append(.text("Active Project: \(xcode.projectRootURL?.path ?? "N/A")"))
                xcodeMenu.items
                    .append(.text("Active Workspace: \(xcode.workspaceURL?.path ?? "N/A")"))
                xcodeMenu.items
                    .append(.text("Active Document: \(xcode.documentURL?.path ?? "N/A")"))

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

            menu.items.append(.separator())

            menu.items.append(NSMenuItem(
                title: "Restart Xcode Inspector",
                action: #selector(restartXcodeInspector),
                keyEquivalent: ""
            ))

        default:
            break
        }
    }
}

import XPCShared

private extension AppDelegate {
    @objc func restartXcodeInspector() {
        Task {
            await XcodeInspector.shared.restart(cleanUp: true)
        }
    }

    @objc func reactivateObservationsToXcode() {
        XcodeInspector.shared.reactivateObservationsToXcode()
    }

    @objc func openExtensionManager() {
        guard let data = try? JSONEncoder().encode(ExtensionServiceRequests.OpenExtensionManager())
        else { return }
        service.handleXPCServiceRequests(
            endpoint: ExtensionServiceRequests.OpenExtensionManager.endpoint,
            requestBody: data,
            reply: { _, _ in }
        )
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

