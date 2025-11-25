import AppKit
import DebounceFunction
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
        [ObjectIdentifier: IDEWorkspaceWindowOverlayWindowController]()
    var updateWindowStateTask: Task<Void, Error>?

    let windowUpdateThrottler = ThrottleRunner(duration: 0.2)

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
                await self.windowUpdateThrottler.throttle { [weak self] in
                    await self?.handleOverlayStatusChange()
                }
            }
        }
    }

    func createNewIDEOverlayWindowController(
        inspector: WorkspaceXcodeWindowInspector,
        application: NSRunningApplication
    ) {
        let id = ObjectIdentifier(inspector)
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
        ideWindowOverlayWindowControllers[id] = newController
    }

    func removeIDEOverlayWindowController(for id: ObjectIdentifier) {
        if let controller = ideWindowOverlayWindowControllers[id] {
            controller.destroy()
        }
        ideWindowOverlayWindowControllers[id] = nil
    }

    func handleSpaceChange() async {
        let windowInspector = XcodeInspector.shared.focusedWindow
        guard let activeWindowController = {
            if let windowInspector = windowInspector as? WorkspaceXcodeWindowInspector {
                let id = ObjectIdentifier(windowInspector)
                return ideWindowOverlayWindowControllers[id]
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

    func handleOverlayStatusChange() {
        guard XcodeInspector.shared.activeApplication?.isXcode ?? false else {
            var closedControllers: [ObjectIdentifier] = []
            for (id, controller) in ideWindowOverlayWindowControllers {
                if controller.isWindowClosed {
                    controller.dim()
                    closedControllers.append(id)
                } else {
                    controller.dim()
                }
            }
            for id in closedControllers {
                removeIDEOverlayWindowController(for: id)
            }
            return
        }

        guard let app = XcodeInspector.shared.activeXcode else {
            for (_, controller) in ideWindowOverlayWindowControllers {
                controller.hide()
            }
            return
        }

        let windowInspector = XcodeInspector.shared.focusedWindow
        if let ideWindowInspector = windowInspector as? WorkspaceXcodeWindowInspector {
            let objectID = ObjectIdentifier(ideWindowInspector)
            // Workspace window is active
            // Hide all controllers first
            for (id, controller) in ideWindowOverlayWindowControllers {
                if id != objectID {
                    controller.hide()
                }
            }
            if let controller = ideWindowOverlayWindowControllers[objectID] {
                controller.access()
            } else {
                createNewIDEOverlayWindowController(
                    inspector: ideWindowInspector,
                    application: app.runningApplication
                )
            }
        } else {
            // Not a workspace window, dim all controllers
            for (_, controller) in ideWindowOverlayWindowControllers {
                controller.dim()
            }
        }
    }
}

