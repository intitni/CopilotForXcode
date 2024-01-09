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
}

public extension FileManager {
    func fileIsDirectory(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileExists(atPath: path, isDirectory: &isDirectory)
        return isDirectory.boolValue && exists
    }
}

