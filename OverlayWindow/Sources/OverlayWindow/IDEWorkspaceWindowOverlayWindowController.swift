import AppKit
import AXExtension
import AXNotificationStream
import Foundation
import Perception
import SwiftUI
import XcodeInspector

@MainActor
public protocol IDEWorkspaceWindowOverlayWindowControllerContentProvider {
    associatedtype Content: View
    func createWindow() -> NSWindow?
    func createContent() -> Content
    func destroy()

    init(windowInspector: WorkspaceXcodeWindowInspector, application: NSRunningApplication)
}

extension IDEWorkspaceWindowOverlayWindowControllerContentProvider {
    var contentBody: AnyView {
        AnyView(createContent())
    }
}

@MainActor
final class IDEWorkspaceWindowOverlayWindowController {
    private var lastAccessDate: Date = .init()
    let application: NSRunningApplication
    let inspector: WorkspaceXcodeWindowInspector
    let contentProviders: [any IDEWorkspaceWindowOverlayWindowControllerContentProvider]
    let maskPanel: OverlayPanel
    var windowElement: AXUIElement
    private var axNotificationTask: Task<Void, Never>?

    init(
        inspector: WorkspaceXcodeWindowInspector,
        application: NSRunningApplication,
        contentProviderFactory: (
            _ windowInspector: WorkspaceXcodeWindowInspector, _ application: NSRunningApplication
        ) -> [any IDEWorkspaceWindowOverlayWindowControllerContentProvider]
    ) {
        self.inspector = inspector
        self.application = application
        let contentProviders = contentProviderFactory(inspector, application)
        self.contentProviders = contentProviders
        windowElement = inspector.uiElement

        let panel = OverlayPanel(
            contentRect: .init(x: 0, y: 0, width: 200, height: 200)
        ) {
            ZStack {
                ForEach(0..<contentProviders.count, id: \.self) { index in
                    contentProviders[index].contentBody
                }
            }
        }
        maskPanel = panel

        for contentProvider in contentProviders {
            if let window = contentProvider.createWindow() {
                panel.addChildWindow(window, ordered: .above)
            }
        }

        observeWindowChange()
    }

    deinit {
        axNotificationTask?.cancel()
    }

    var isWindowClosed: Bool {
        inspector.isInvalid
    }

    func access() {
        lastAccessDate = Date()
        maskPanel.level = overlayLevel(0)
        maskPanel.setIsVisible(true)
        maskPanel.orderFrontRegardless()

        // When macOS awakes from sleep, the AXUIElement reference may become invalid.
        if windowElement.parent == nil {
            windowElement = inspector.uiElement
            observeWindowChange()
        } else {
            updateFrame()
        }
    }

    func dim() {
        maskPanel.level = .normal
    }

    func hide() {
        maskPanel.setIsVisible(false)
        maskPanel.level = .normal
    }

    func destroy() {
        maskPanel.close()
        for contentProvider in contentProviders {
            contentProvider.destroy()
        }
    }

    private func observeWindowChange() {
        axNotificationTask?.cancel()

        let stream = AXNotificationStream(
            app: application,
            element: windowElement,
            notificationNames:
            kAXMovedNotification,
            kAXResizedNotification,
            kAXWindowMiniaturizedNotification,
            kAXWindowDeminiaturizedNotification
        )

        axNotificationTask = Task { [weak self] in
            for await notification in stream {
                guard let self else { return }
                if Task.isCancelled { return }
                switch notification.name {
                case kAXMovedNotification, kAXResizedNotification:
                    self.updateFrame()
                case kAXWindowMiniaturizedNotification:
                    self.hide()
                default: continue
                }
            }
        }

        updateFrame()
    }

    private func updateFrame() {
        if let rect = windowElement.rect {
            maskPanel.setTopLeftCoordinateFrame(rect, display: false)
        }
    }
}

