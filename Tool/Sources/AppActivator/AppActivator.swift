import AppKit
import Dependencies
import XcodeInspector

public extension NSWorkspace {
    static func activateThisApp(delay: TimeInterval = 0.5) {
        Task { @MainActor in
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            // NSApp.activate may fail.
            NSRunningApplication(
                processIdentifier: ProcessInfo.processInfo.processIdentifier
            )?.activate()
        }
    }

    static func activatePreviousActiveApp(delay: TimeInterval = 0.2) {
        Task { @MainActor in
            guard let app = XcodeInspector.shared.previousActiveApplication else { return }
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            app.runningApplication.activate()
        }
    }
    
    static func activatePreviousActiveXcode(delay: TimeInterval = 0.2) {
        Task { @MainActor in
            guard let app = XcodeInspector.shared.latestActiveXcode else { return }
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            app.runningApplication.activate()
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

