import ActiveApplicationMonitor
import AppKit
import AXExtension
import Foundation
import Logger
import Preferences
import XcodeInspector

public struct NoAccessToAccessibilityAPIError: Error, LocalizedError {
    public var errorDescription: String? {
        "Accessibility API permission is not granted. Please enable in System Settings.app."
    }

    public init() {}
}

public struct FailedToFetchFileURLError: Error, LocalizedError {
    public var errorDescription: String? {
        "Failed to fetch editing file url."
    }

    public init() {}
}

public enum Environment {
    public static var now = { Date() }

    public static var isXcodeActive: () async -> Bool = {
        ActiveApplicationMonitor.shared.activeXcode != nil
    }

    public static var frontmostXcodeWindowIsEditor: () async -> Bool = {
        let appleScript = """
        tell application "Xcode"
            return path of document of the first window
        end tell
        """
        do {
            let result = try await runAppleScript(appleScript)
            return !result.isEmpty
        } catch {
            return false
        }
    }

    #warning("TODO: Use XcodeInspector instead.")
    public static var fetchCurrentWorkspaceURLFromXcode: () async throws -> URL? = {
        if let xcode = ActiveApplicationMonitor.shared.activeXcode
            ?? ActiveApplicationMonitor.shared.latestXcode
        {
            let application = AXUIElementCreateApplication(xcode.processIdentifier)
            let focusedWindow = application.focusedWindow
            for child in focusedWindow?.children ?? [] {
                if child.description.starts(with: "/"), child.description.count > 1 {
                    let path = child.description
                    let trimmedNewLine = path.trimmingCharacters(in: .newlines)
                    var url = URL(fileURLWithPath: trimmedNewLine)
                    return url
                }
            }
        }

        return nil
    }

    public static var fetchCurrentProjectRootURLFromXcode: () async throws -> URL? = {
        if var url = try await fetchCurrentWorkspaceURLFromXcode() {
            return try await guessProjectRootURLForFile(url)
        }

        return nil
    }

    #warning("TODO: Use WorkspaceXcodeWindowInspector.extractProjectURL instead.")
    public static var guessProjectRootURLForFile: (_ fileURL: URL) async throws -> URL = {
        fileURL in
        var currentURL = fileURL
        var firstDirectoryURL: URL?
        var lastGitDirectoryURL: URL?
        while currentURL.pathComponents.count > 1 {
            defer { currentURL.deleteLastPathComponent() }
            guard FileManager.default.fileIsDirectory(atPath: currentURL.path) else { continue }
            guard currentURL.pathExtension != "xcodeproj" else { continue }
            guard currentURL.pathExtension != "xcworkspace" else { continue }
            guard currentURL.pathExtension != "playground" else { continue }
            if firstDirectoryURL == nil { firstDirectoryURL = currentURL }
            let gitURL = currentURL.appendingPathComponent(".git")
            if FileManager.default.fileIsDirectory(atPath: gitURL.path) {
                lastGitDirectoryURL = currentURL
            } else if let text = try? String(contentsOf: gitURL) {
                if !text.hasPrefix("gitdir: ../"), // it's not a sub module
                   text.range(of: "/.git/worktrees/") != nil // it's a git worktree
                {
                    lastGitDirectoryURL = currentURL
                }
            }
        }

        return lastGitDirectoryURL ?? firstDirectoryURL ?? fileURL
    }

    public static var fetchCurrentFileURL: () async throws -> URL = {
        guard let xcode = ActiveApplicationMonitor.shared.activeXcode
            ?? ActiveApplicationMonitor.shared.latestXcode
        else {
            throw FailedToFetchFileURLError()
        }

        // fetch file path of the frontmost window of Xcode through Accessability API.
        let application = AXUIElementCreateApplication(xcode.processIdentifier)
        let focusedWindow = application.focusedWindow
        var path = focusedWindow?.document
        if path == nil {
            for window in application.windows {
                path = window.document
                if path != nil { break }
            }
        }
        if let path = path?.removingPercentEncoding {
            let url = URL(
                fileURLWithPath: path
                    .replacingOccurrences(of: "file://", with: "")
            )
            return url
        }
        throw FailedToFetchFileURLError()
    }

    public static var fetchFocusedElementURI: () async throws -> URL = {
        guard let xcode = ActiveApplicationMonitor.shared.activeXcode
            ?? ActiveApplicationMonitor.shared.latestXcode
        else { return URL(fileURLWithPath: "/global") }

        let application = AXUIElementCreateApplication(xcode.processIdentifier)
        let focusedElement = application.focusedElement
        var windowElement: URL {
            let window = application.focusedWindow
            let id = window?.identifier.hashValue
            return URL(fileURLWithPath: "/xcode-focused-element/\(id ?? 0)")
        }
        if focusedElement?.description != "Source Editor" {
            return windowElement
        }

        do {
            return try await fetchCurrentFileURL()
        } catch {
            return windowElement
        }
    }

    public static var triggerAction: (_ name: String) async throws -> Void = { name in
        struct CantRunCommand: Error, LocalizedError {
            let name: String
            var errorDescription: String? {
                "Can't run command \(name)."
            }
        }

        guard let activeXcode = XcodeInspector.shared.latestActiveXcode?.runningApplication
        else { throw CantRunCommand(name: name) }

        let bundleName = Bundle.main
            .object(forInfoDictionaryKey: "EXTENSION_BUNDLE_NAME") as! String

        await Task.yield()

        if UserDefaults.shared.value(for: \.triggerActionWithAccessibilityAPI) {
            if !activeXcode.isActive { activeXcode.activate() }
            let app = AXUIElementCreateApplication(activeXcode.processIdentifier)

            if let editorMenu = app.menuBar?.child(title: "Editor"),
               let commandMenu = editorMenu.child(title: bundleName)
            {
                if let button = commandMenu.child(title: name, role: "AXMenuItem") {
                    let error = AXUIElementPerformAction(button, kAXPressAction as CFString)
                    if error != AXError.success {
                        Logger.service
                            .error("Trigger command \(name) failed: \(error.localizedDescription)")
                        throw error
                    } else {
                        return
                    }
                }
            } else if let commandMenu = app.menuBar?.child(title: bundleName),
                      let button = commandMenu.child(title: name, role: "AXMenuItem")
            {
                let error = AXUIElementPerformAction(button, kAXPressAction as CFString)
                if error != AXError.success {
                    Logger.service
                        .error("Trigger command \(name) failed: \(error.localizedDescription)")
                    throw error
                } else {
                    return
                }
            }

            throw CantRunCommand(name: name)
        } else {
            /// check if menu is open, if not, click the menu item.
            let appleScript = """
            tell application "System Events"
                set theprocs to every process whose unix id is \(activeXcode.processIdentifier)
                repeat with proc in theprocs
                set the frontmost of proc to true
                    tell proc
                        repeat with theMenu in menus of menu bar 1
                            set theValue to value of attribute "AXVisibleChildren" of theMenu
                            if theValue is not {} then
                                return
                            end if
                        end repeat
                        click menu item "\(name)" of menu 1 of menu item "\(bundleName)" of menu 1 of menu bar item "Editor" of menu bar 1
                    end tell
                end repeat
            end tell
            """

            do {
                try await runAppleScript(appleScript)
            } catch {
                Logger.service
                    .error("Trigger command \(name) failed: \(error.localizedDescription)")
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

public extension FileManager {
    func fileIsDirectory(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileExists(atPath: path, isDirectory: &isDirectory)
        return isDirectory.boolValue && exists
    }
}

