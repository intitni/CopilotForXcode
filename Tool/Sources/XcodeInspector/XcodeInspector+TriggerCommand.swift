import AppKit
import AXExtension
import Foundation
import Logger

public extension XcodeAppInstanceInspector {
    func triggerCopilotCommand(name: String, activateXcode: Bool = true) async throws {
        let bundleName = Bundle.main
            .object(forInfoDictionaryKey: "EXTENSION_BUNDLE_NAME") as! String
        try await triggerMenuItem(path: ["Editor", bundleName, name], activateXcode: activateXcode)
    }
}

public extension AppInstanceInspector {
    @MainActor
    func triggerMenuItem(path: [String], activateXcode: Bool) async throws {
        guard !path.isEmpty else { return }

        struct CantRunCommand: Error, LocalizedError {
            let path: [String]
            var errorDescription: String? {
                "Can't run command \(path.joined(separator: "/"))."
            }
        }

        if activateXcode {
            if !runningApplication.activate() {
                throw CantRunCommand(path: path)
            }
        } else {
            if !runningApplication.isActive {
                throw CantRunCommand(path: path)
            }
        }

        await Task.yield()

        if UserDefaults.shared.value(for: \.triggerActionWithAccessibilityAPI) {
            let app = AXUIElementCreateApplication(runningApplication.processIdentifier)
            guard let menuBar = app.menuBar else { throw CantRunCommand(path: path) }
            var path = path
            var currentMenu = menuBar
            while !path.isEmpty {
                let item = path.removeFirst()

                if path.isEmpty, let button = currentMenu.child(title: item, role: "AXMenuItem") {
                    let error = AXUIElementPerformAction(button, kAXPressAction as CFString)
                    if error != AXError.success {
                        Logger.service.error("""
                        Trigger menu item \(path.joined(separator: "/")) failed: \
                        \(error.localizedDescription)
                        """)
                        throw error
                    } else {
                        return
                    }
                } else if let menu = currentMenu.child(title: item) {
                    currentMenu = menu
                } else {
                    throw CantRunCommand(path: path)
                }
            }
        } else {
            guard path.count >= 2 else { throw CantRunCommand(path: path) }

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
                throw error
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

