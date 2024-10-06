import AppKit
import AXExtension
import Foundation
import Logger

public extension XcodeAppInstanceInspector {
    func triggerCopilotCommand(name: String, activateXcode: Bool = true) async throws {
        let bundleName = Bundle.main
            .object(forInfoDictionaryKey: "EXTENSION_BUNDLE_NAME") as! String
        try await triggerMenuItem(path: ["Editor", bundleName, name], activateApp: activateXcode)
    }
}

public extension AppInstanceInspector {
    struct CantRunCommand: Error, LocalizedError {
        let path: String
        let reason: String
        public var errorDescription: String? {
            "Can't run command \(path): \(reason)"
        }
    }

    @MainActor
    func triggerMenuItem(path: [String], activateApp: Bool) async throws {
        let sourcePath = path.joined(separator: "/")
        func cantRunCommand(_ reason: String) -> CantRunCommand {
            return CantRunCommand(path: sourcePath, reason: reason)
        }

        guard path.count >= 2 else { throw cantRunCommand("Path too short.") }

        if activateApp {
            if !runningApplication.activate() {
                Logger.service.error("""
                Trigger menu item \(sourcePath): \
                Xcode not activated.
                """)
            }
        } else {
            if !runningApplication.isActive {
                Logger.service.error("""
                Trigger menu item \(sourcePath): \
                Xcode not activated.
                """)
            }
        }

        await Task.yield()

        if UserDefaults.shared.value(for: \.triggerActionWithAccessibilityAPI) {
            let app = AXUIElementCreateApplication(runningApplication.processIdentifier)

            guard let menuBar = app.menuBar else {
                Logger.service.error("""
                Trigger menu item \(sourcePath) failed: \
                Menu not found.
                """)
                throw cantRunCommand("Menu not found.")
            }
            var path = path
            var currentMenu = menuBar
            while !path.isEmpty {
                let item = path.removeFirst()

                if path.isEmpty, let button = currentMenu.child(title: item, role: "AXMenuItem") {
                    let error = AXUIElementPerformAction(button, kAXPressAction as CFString)
                    if error != AXError.success {
                        Logger.service.error("""
                        Trigger menu item \(sourcePath) failed: \
                        \(error.localizedDescription)
                        """)
                        throw cantRunCommand(error.localizedDescription)
                    } else {
                        #if DEBUG
                        Logger.service.info("""
                        Trigger menu item \(sourcePath) succeeded.
                        """)
                        #endif
                        return
                    }
                } else if let menu = currentMenu.child(title: item) {
                    #if DEBUG
                    Logger.service.info("""
                    Trigger menu item \(sourcePath): Move to \(item).
                    """)
                    #endif
                    currentMenu = menu
                } else {
                    Logger.service.error("""
                    Trigger menu item \(sourcePath) failed: \
                    \(item) is not found.
                    """)
                    throw cantRunCommand("\(item) is not found.")
                }
            }
        } else {
            let clickTask = {
                var path = path
                let button = path.removeLast()
                let menuBarItem = path.removeFirst()
                let list = path
                    .reversed()
                    .map { "menu 1 of menu item \"\($0)\"" }
                    .joined(separator: " of ")
                return """
                click menu item "\(button)" of \(list) \
                of menu 1 \
                of menu bar item "\(menuBarItem)" \
                of menu bar 1
                """
            }()
            /// check if menu is open, if not, click the menu item.
            let appleScript = """
            tell application "System Events"
                set theprocs to every process whose unix id is \
                \(runningApplication.processIdentifier)
                repeat with proc in theprocs
                    tell proc
                        repeat with theMenu in menus of menu bar 1
                            set theValue to value of attribute "AXVisibleChildren" of theMenu
                            if theValue is not {} then
                                return
                            end if
                        end repeat
                        \(clickTask)
                    end tell
                end repeat
            end tell
            """

            do {
                try await runAppleScript(appleScript)
            } catch {
                Logger.service.error("""
                Trigger menu item \(path.joined(separator: "/")) failed: \
                \(error.localizedDescription)
                """)
                throw cantRunCommand(error.localizedDescription)
            }
        }
    }
}

@discardableResult
func runAppleScript(_ appleScript: String) async throws -> String {
    let task = Process()
    task.launchPath = "/usr/bin/osascript"
    task.arguments = ["-e", appleScript]
    let outpipe = Pipe()
    task.standardOutput = outpipe
    task.standardError = Pipe()

    return try await withUnsafeThrowingContinuation { continuation in
        do {
            task.terminationHandler = { _ in
                do {
                    if let data = try outpipe.fileHandleForReading.readToEnd(),
                       let content = String(data: data, encoding: .utf8)
                    {
                        continuation.resume(returning: content)
                        return
                    }
                    continuation.resume(returning: "")
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            try task.run()
        } catch {
            continuation.resume(throwing: error)
        }
    }
}

