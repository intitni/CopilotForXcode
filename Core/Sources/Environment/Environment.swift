import ActiveApplicationMonitor
import AppKit
import AXExtension
import Foundation
import GitHubCopilotService
import Logger
import SuggestionService

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
        ActiveApplicationMonitor.activeXcode != nil
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

    public static var fetchCurrentProjectRootURL: (_ fileURL: URL?) async throws
        -> URL? = { fileURL in
            if let xcode = ActiveApplicationMonitor.activeXcode
                ?? ActiveApplicationMonitor.latestXcode
            {
                let application = AXUIElementCreateApplication(xcode.processIdentifier)
                let focusedWindow = application.focusedWindow
                for child in focusedWindow?.children ?? [] {
                    if child.description.starts(with: "/"), child.description.count > 1 {
                        let path = child.description
                        let trimmedNewLine = path.trimmingCharacters(in: .newlines)
                        var url = URL(fileURLWithPath: trimmedNewLine)
                        while !FileManager.default.fileIsDirectory(atPath: url.path) ||
                            !url.pathExtension.isEmpty
                        {
                            url = url.deletingLastPathComponent()
                        }
                        return url
                    }
                }
            }

            guard var currentURL = fileURL else { return nil }
            var firstDirectoryURL: URL?
            while currentURL.pathComponents.count > 1 {
                defer { currentURL.deleteLastPathComponent() }
                guard FileManager.default.fileIsDirectory(atPath: currentURL.path) else { continue }
                if firstDirectoryURL == nil { firstDirectoryURL = currentURL }
                let gitURL = currentURL.appendingPathComponent(".git")
                if FileManager.default.fileIsDirectory(atPath: gitURL.path) {
                    return currentURL
                }
            }

            return firstDirectoryURL ?? fileURL
        }

    public static var fetchCurrentFileURL: () async throws -> URL = {
        guard let xcode = ActiveApplicationMonitor.activeXcode
            ?? ActiveApplicationMonitor.latestXcode
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
        guard let xcode = ActiveApplicationMonitor.activeXcode
            ?? ActiveApplicationMonitor.latestXcode
        else {
            throw FailedToFetchFileURLError()
        }

        let application = AXUIElementCreateApplication(xcode.processIdentifier)
        let focusedElement = application.focusedElement
        if focusedElement?.description != "Source Editor" {
            let window = application.focusedWindow
            let id = window?.identifier.hashValue
            return URL(fileURLWithPath: "/xcode-focused-element/\(id ?? 0)")
        }

        return try await fetchCurrentFileURL()
    }

    public static var createSuggestionService: (_ projectRootURL: URL)
        -> SuggestionServiceType = { projectRootURL in
            SuggestionService(projectRootURL: projectRootURL)
        }

    public static var triggerAction: (_ name: String) async throws -> Void = { name in
        guard let activeXcode = ActiveApplicationMonitor.activeXcode
            ?? ActiveApplicationMonitor.latestXcode
        else { return }
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
                            .error("Trigger action \(name) failed: \(error.localizedDescription)")
                        throw error
                    }
                }
            } else if let commandMenu = app.menuBar?.child(title: bundleName),
                      let button = commandMenu.child(title: name, role: "AXMenuItem")
            {
                let error = AXUIElementPerformAction(button, kAXPressAction as CFString)
                if error != AXError.success {
                    Logger.service
                        .error("Trigger action \(name) failed: \(error.localizedDescription)")
                    throw error
                }
            } else {
                struct CantRunCommand: Error, LocalizedError {
                    let name: String
                    var errorDescription: String? {
                        "Can't run command \(name)."
                    }
                }

                throw CantRunCommand(name: name)
            }
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
                    .error("Trigger action \(name) failed: \(error.localizedDescription)")
                throw error
            }
        }
    }

    public static var makeXcodeActive: () async throws -> Void = {
        let appleScript = """
        tell application "Xcode"
            activate
        end tell
        """
        try await runAppleScript(appleScript)
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

extension FileManager {
    func fileIsDirectory(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileExists(atPath: path, isDirectory: &isDirectory)
        return isDirectory.boolValue && exists
    }
}

