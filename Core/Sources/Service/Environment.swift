import AppKit
import CopilotService
import Foundation

private struct NoAccessToAccessibilityAPIError: Error, LocalizedError {
    var errorDescription: String? {
        "Permission not granted to use Accessibility API. Please turn in on in System Settings.app."
    }
}

private struct FailedToFetchFileURLError: Error, LocalizedError {
    var errorDescription: String? {
        "Failed to fetch editing file url."
    }
}

enum Environment {
    static var now = { Date() }

    static var runningXcodes: () async -> [NSRunningApplication] = {
        var xcodes = [NSRunningApplication]()
        var retryCount = 0
        // Sometimes runningApplications returns 0 items.
        while xcodes.isEmpty, retryCount < 3 {
            xcodes = NSRunningApplication
                .runningApplications(withBundleIdentifier: "com.apple.dt.Xcode")
            try? await Task.sleep(nanoseconds: 1_000_000)
            retryCount += 1
        }
        return xcodes
    }

    static var isXcodeActive: () async -> Bool = {
        var activeXcodes = [NSRunningApplication]()
        var retryCount = 0
        // Sometimes runningApplications returns 0 items.
        while activeXcodes.isEmpty, retryCount < 3 {
            activeXcodes = NSRunningApplication
                .runningApplications(withBundleIdentifier: "com.apple.dt.Xcode")
                .filter(\.isActive)
            try? await Task.sleep(nanoseconds: 1_000_000)
            retryCount += 1
        }
        return !activeXcodes.isEmpty
    }
    
    static var frontmostXcodeWindowIsEditor: () async -> Bool = {
        let appleScript = """
        tell application "Xcode"
            return path of document of the first window
        end tell
        """
        do {
            let result = try await runAppleScript(appleScript)
            return !result.isEmpty
        }
        catch {
            return false
        }
    }

    static var fetchCurrentProjectRootURL: (_ fileURL: URL?) async throws -> URL? = { fileURL in
        let appleScript = """
        tell application "Xcode"
            return path of document of the first window
        end tell
        """

        let path = (try? await runAppleScript(appleScript)) ?? ""
        if !path.isEmpty {
            let trimmedNewLine = path.trimmingCharacters(in: .newlines)
            var url = URL(fileURLWithPath: trimmedNewLine)
            while !FileManager.default.fileIsDirectory(atPath: url.path) ||
                !url.pathExtension.isEmpty
            {
                url = url.deletingLastPathComponent()
            }
            return url
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

    static var fetchCurrentFileURL: () async throws -> URL = {
        var activeXcodes = [NSRunningApplication]()
        var retryCount = 0
        // Sometimes runningApplications returns 0 items.
        while activeXcodes.isEmpty, retryCount < 5 {
            activeXcodes = NSRunningApplication
                .runningApplications(withBundleIdentifier: "com.apple.dt.Xcode")
                .sorted { lhs, _ in
                    if lhs.isActive { return true }
                    return false
                }
            if retryCount > 0 { try await Task.sleep(nanoseconds: 10_000_000) }
            retryCount += 1
        }

        // fetch file path of the frontmost window of Xcode through Accessability API.
        for xcode in activeXcodes {
            let application = AXUIElementCreateApplication(xcode.processIdentifier)
            do {
                let frontmostWindow = try application.copyValue(
                    key: kAXFocusedWindowAttribute,
                    ofType: AXUIElement.self
                )
                var path = try? frontmostWindow.copyValue(
                    key: kAXDocumentAttribute,
                    ofType: String?.self
                )
                if path == nil {
                    for window in try application.copyValue(
                        key: kAXWindowsAttribute,
                        ofType: [AXUIElement].self
                    ) {
                        path = try? window.copyValue(
                            key: kAXDocumentAttribute,
                            ofType: String?.self
                        )
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
            } catch {
                if let axError = error as? AXError, axError == .apiDisabled {
                    throw NoAccessToAccessibilityAPIError()
                }
            }
        }

        throw FailedToFetchFileURLError()
    }

    static var createAuthService: () -> CopilotAuthServiceType = {
        CopilotAuthService()
    }

    static var createSuggestionService: (_ projectRootURL: URL)
        -> CopilotSuggestionServiceType = { projectRootURL in
            CopilotSuggestionService(projectRootURL: projectRootURL)
        }

    static var triggerAction: (_ name: String) async throws -> Void = { name in
        var xcodes = [NSRunningApplication]()
        var retryCount = 0
        // Sometimes runningApplications returns 0 items.
        while xcodes.isEmpty, retryCount < 5 {
            xcodes = NSRunningApplication
                .runningApplications(withBundleIdentifier: "com.apple.dt.Xcode")
            if retryCount > 0 { try await Task.sleep(nanoseconds: 10_000_000) }
            retryCount += 1
        }

        guard let activeXcode = xcodes.first(where: { $0.isActive }) else { return }
        let bundleName = Bundle.main
            .object(forInfoDictionaryKey: "EXTENSION_BUNDLE_NAME") as! String

        /// check if menu is open, if not, click the menu item.
        let appleScript = """
        tell application "System Events"
            set proc to item 1 of (processes whose unix id is \(activeXcode.processIdentifier))
            tell proc
                repeat with theMenu in menus of menu bar 1
                    set theValue to value of attribute "AXVisibleChildren" of theMenu
                    if theValue is not {} then
                        return
                    end if
                end repeat
                click menu item "\(name)" of menu 1 of menu item "\(bundleName)" of menu 1 of menu bar item "Editor" of menu bar 1
            end tell
        end tell
        """

        try await runAppleScript(appleScript)
    }
}

extension AXError: Error {}

extension AXUIElement {
    func copyValue<T>(key: String, ofType _: T.Type = T.self) throws -> T {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(self, key as CFString, &value)
        if error == .success, let value = value as? T {
            return value
        }
        throw error
    }
}
