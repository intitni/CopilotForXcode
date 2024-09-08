import AppKit
import Dependencies
import XcodeInspector

public extension NSWorkspace {
    static func activateThisApp(delay: TimeInterval = 0.10) {
        Task { @MainActor in
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            // NSApp.activate may fail. And since macOS 14, it looks like the app needs other
            // apps to call `yieldActivationToApplication` to activate itself?

            let activated = NSRunningApplication.current
                .activate(options: [.activateIgnoringOtherApps])

            if activated { return }

            // Fallback solution

            let appleScript = """
            tell application "System Events"
                set frontmost of the first process whose unix id is \
            \(ProcessInfo.processInfo.processIdentifier) to true
            end tell
            """
            try await runAppleScript(appleScript)
        }
    }

    static func activatePreviousActiveApp(delay: TimeInterval = 0.2) {
        Task { @MainActor in
            guard let app = await XcodeInspector.shared.safe.previousActiveApplication
            else { return }
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            _ = app.activate()
        }
    }

    static func activatePreviousActiveXcode(delay: TimeInterval = 0.2) {
        Task { @MainActor in
            guard let app = await XcodeInspector.shared.safe.latestActiveXcode else { return }
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            _ = app.activate()
        }
    }
}

struct ActivateThisAppDependencyKey: DependencyKey {
    static var liveValue: () -> Void = { NSWorkspace.activateThisApp() }
}

struct ActivatePreviousActiveAppDependencyKey: DependencyKey {
    static var liveValue: () -> Void = { NSWorkspace.activatePreviousActiveApp() }
}

struct ActivatePreviousActiveXcodeDependencyKey: DependencyKey {
    static var liveValue: () -> Void = { NSWorkspace.activatePreviousActiveXcode() }
}

public extension DependencyValues {
    var activateThisApp: () -> Void {
        get { self[ActivateThisAppDependencyKey.self] }
        set { self[ActivateThisAppDependencyKey.self] = newValue }
    }

    var activatePreviousActiveApp: () -> Void {
        get { self[ActivatePreviousActiveAppDependencyKey.self] }
        set { self[ActivatePreviousActiveAppDependencyKey.self] = newValue }
    }

    var activatePreviousActiveXcode: () -> Void {
        get { self[ActivatePreviousActiveXcodeDependencyKey.self] }
        set { self[ActivatePreviousActiveXcodeDependencyKey.self] = newValue }
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

