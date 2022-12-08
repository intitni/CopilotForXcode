import AppKit
import Foundation
import CopilotService

private struct NoAccessToAccessibilityAPIError: Error, LocalizedError {
    var errorDescription: String? {
        "Permission not granted to use Accessibility API. Please turn in on in Settings.app."
    }
}
private struct FailedToFetchFileURLError: Error, LocalizedError {
    var errorDescription: String? {
        "Failed to fetch editing file url."
    }
}

enum Environment {
    static var now = { Date() }

    static var fetchCurrentProjectRootURL: () async throws -> URL? = {
        let appleScript = """
        tell application "Xcode"
            return path of document of the first window
        end tell
        """

        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", appleScript]
        let outpipe = Pipe()
        task.standardOutput = outpipe
        try task.run()
        await Task.yield()
        task.waitUntilExit()
        if let data = try outpipe.fileHandleForReading.readToEnd(),
           let path = String(data: data, encoding: .utf8)
        {
            let trimmedNewLine = path.trimmingCharacters(in: .newlines)
            var url = URL(fileURLWithPath: trimmedNewLine)
            while !FileManager.default.fileIsDirectory(atPath: url.path) ||
                !url.pathExtension.isEmpty
            {
                url = url.deletingLastPathComponent()
            }
            return url
        }
        return nil
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
            if retryCount > 0 { try await Task.sleep(nanoseconds: 50_000_000) }
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
                var path = try frontmostWindow.copyValue(
                    key: kAXDocumentAttribute,
                    ofType: String?.self
                )
                if path == nil {
                    if let firstWindow = try application.copyValue(
                        key: kAXWindowsAttribute,
                        ofType: [AXUIElement].self
                    ).first {
                        path = try firstWindow.copyValue(
                            key: kAXDocumentAttribute,
                            ofType: String.self
                        )
                    }
                }
                if let path {
                    return URL(fileURLWithPath: path)
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
        return CopilotAuthService()
    }
    
    static var createSuggestionService: (_ projectRootURL: URL) -> CopilotSuggestionServiceType = { projectRootURL in
        return CopilotSuggestionService(projectRootURL: projectRootURL)
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
