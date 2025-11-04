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

    var ideWindowOverlayWindowControllers: [URL: IDEWorkspaceWindowOverlayWindowController] = [:]

    public init() {}

    public func start() {
        observeEvents()
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
    }
}

private extension OverlayWindowController {
    func observeWindowChange() {
        if ideWindowOverlayWindowControllers.isEmpty {
            if let app = XcodeInspector.shared.activeXcode,
               let windowInspector = XcodeInspector.shared
               .focusedWindow as? WorkspaceXcodeWindowInspector
            {
                let workspaceURL = windowInspector.workspaceURL
                createNewIDEOverlayWindowController(
                    for: workspaceURL,
                    inspector: windowInspector,
                    application: app.runningApplication
                )
            }
        }

        withPerceptionTracking {
            _ = XcodeInspector.shared.focusedWindow
            _ = XcodeInspector.shared.activeXcode
        } onChange: { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                defer { self.observeWindowChange() }

                guard let app = XcodeInspector.shared.activeXcode else {
                    for (_, controller) in self.ideWindowOverlayWindowControllers {
                        controller.hide()
                    }
                    return
                }

                let windowInspector = XcodeInspector.shared.focusedWindow
                if let ideWindowInspector = windowInspector as? WorkspaceXcodeWindowInspector {
                    let workspaceURL = ideWindowInspector.workspaceURL
                    // Workspace window is active
                    // Hide all controllers first
                    for (url, controller) in self.ideWindowOverlayWindowControllers {
                        if url != workspaceURL {
                            controller.hide()
                        }
                    }
                    if let controller = self.ideWindowOverlayWindowControllers[workspaceURL] {
                        controller.access()
                    } else {
                        self.createNewIDEOverlayWindowController(
                            for: workspaceURL,
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
        for workspaceURL: URL,
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
        ideWindowOverlayWindowControllers[workspaceURL] = newController
    }
}

