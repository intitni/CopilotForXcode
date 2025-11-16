import AppKit
import Foundation
import Perception
import XcodeInspector

@MainActor
public final class OverlayWindowController {
    public typealias IDEWorkspaceWindowOverlayWindowControllerContentProviderFactory =
        @MainActor @Sendable (
            _ windowInspector: WorkspaceXcodeWindowInspector,
            _ application: NSRunningApplication
        ) -> any IDEWorkspaceWindowOverlayWindowControllerContentProvider

    static var ideWindowOverlayWindowControllerContentProviderFactories:
        [IDEWorkspaceWindowOverlayWindowControllerContentProviderFactory] = []

    var ideWindowOverlayWindowControllers =
        [CGWindowID: IDEWorkspaceWindowOverlayWindowController]()
    var updateWindowStateTask: Task<Void, Error>?

    lazy var fullscreenDetector = {
        let it = NSWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        it.hasShadow = false
        it.setIsVisible(false)
        return it
    }()

    public init() {}

    public func start() {
        observeEvents()
        _ = fullscreenDetector
    }

    public nonisolated static func registerIDEWorkspaceWindowOverlayWindowControllerContentProviderFactory(
        _ factory: @escaping IDEWorkspaceWindowOverlayWindowControllerContentProviderFactory
    ) {
        Task { @MainActor in
            ideWindowOverlayWindowControllerContentProviderFactories.append(factory)
        }
    }
}

extension OverlayWindowController {
    func observeEvents() {
        observeWindowChange()

        updateWindowStateTask = Task { [weak self] in
            if let self { await handleSpaceChange() }

            await withThrowingTaskGroup(of: Void.self) { [weak self] group in
                // active space did change
                _ = group.addTaskUnlessCancelled { [weak self] in
                    let sequence = NSWorkspace.shared.notificationCenter
                        .notifications(named: NSWorkspace.activeSpaceDidChangeNotification)
                    for await _ in sequence {
                        guard let self else { return }
                        try Task.checkCancellation()
                        await handleSpaceChange()
                    }
                }
            }
        }
    }
}

private extension OverlayWindowController {
    func observeWindowChange() {
        if ideWindowOverlayWindowControllers.isEmpty {
            if let app = XcodeInspector.shared.activeXcode,
               let windowInspector = XcodeInspector.shared
               .focusedWindow as? WorkspaceXcodeWindowInspector
            {
                createNewIDEOverlayWindowController(
                    for: windowInspector.windowID,
                    inspector: windowInspector,
                    application: app.runningApplication
                )
            }
        }

        withPerceptionTracking {
            _ = XcodeInspector.shared.focusedWindow
            _ = XcodeInspector.shared.activeXcode
            _ = XcodeInspector.shared.activeApplication
        } onChange: { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                defer { self.observeWindowChange() }

                guard XcodeInspector.shared.activeApplication?.isXcode ?? false else {
                    var closedControllers: [CGWindowID] = []
                    for (id, controller) in self.ideWindowOverlayWindowControllers {
                        if controller.isWindowClosed {
                            controller.dim()
                            closedControllers.append(id)
                        } else {
                            controller.dim()
                        }
                    }
                    for id in closedControllers {
                        self.removeIDEOverlayWindowController(for: id)
                    }
                    return
                }

                guard let app = XcodeInspector.shared.activeXcode else {
                    for (_, controller) in self.ideWindowOverlayWindowControllers {
                        controller.hide()
                    }
                    return
                }

                let windowInspector = XcodeInspector.shared.focusedWindow
                if let ideWindowInspector = windowInspector as? WorkspaceXcodeWindowInspector {
                    let windowID = ideWindowInspector.windowID
                    // Workspace window is active
                    // Hide all controllers first
                    for (id, controller) in self.ideWindowOverlayWindowControllers {
                        if id != windowID {
                            controller.hide()
                        }
                    }
                    if let controller = self.ideWindowOverlayWindowControllers[windowID] {
                        controller.access()
                    } else {
                        self.createNewIDEOverlayWindowController(
                            for: windowID,
                            inspector: ideWindowInspector,
                            application: app.runningApplication
                        )
                    }
                } else {
                    // Not a workspace window, dim all controllers
                    for (_, controller) in self.ideWindowOverlayWindowControllers {
                        controller.dim()
                    }
                }
            }
        }
    }

    func createNewIDEOverlayWindowController(
        for windowID: CGWindowID,
        inspector: WorkspaceXcodeWindowInspector,
        application: NSRunningApplication
    ) {
        let newController = IDEWorkspaceWindowOverlayWindowController(
            inspector: inspector,
            application: application,
            contentProviderFactory: {
                windowInspector, application in
                OverlayWindowController.ideWindowOverlayWindowControllerContentProviderFactories
                    .map { $0(windowInspector, application) }
            }
        )
        newController.access()
        ideWindowOverlayWindowControllers[windowID] = newController
    }

    func removeIDEOverlayWindowController(for id: CGWindowID) {
        if let controller = ideWindowOverlayWindowControllers[id] {
            controller.destroy()
        }
        ideWindowOverlayWindowControllers[id] = nil
    }

    func handleSpaceChange() async {
        let windowInspector = XcodeInspector.shared.focusedWindow
        guard let activeWindowController = {
            if let windowInspector = windowInspector as? WorkspaceXcodeWindowInspector {
                return ideWindowOverlayWindowControllers[windowInspector.windowID]
            } else {
                return nil
            }
        }() else { return }

        let activeXcode = XcodeInspector.shared.activeXcode
        let xcode = activeXcode?.appElement
        let isXcodeActive = xcode?.isFrontmost ?? false
        if isXcodeActive {
            activeWindowController.maskPanel.moveToActiveSpace()
        }

        if fullscreenDetector.isOnActiveSpace, xcode?.focusedWindow != nil {
            activeWindowController.maskPanel.orderFrontRegardless()
        }
    }
}

