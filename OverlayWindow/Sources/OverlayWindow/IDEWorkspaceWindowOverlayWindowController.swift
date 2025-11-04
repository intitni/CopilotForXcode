import AppKit
import AXExtension
import AXNotificationStream
import Foundation
import SwiftUI
import XcodeInspector

public protocol IDEWorkspaceWindowOverlayWindowControllerContentProvider {
    associatedtype Content: View
    func createWindow() -> NSWindow?
    func createContent() -> Content

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
    private var isDestroyed: Bool = false
    private let maskPanel: NSPanel
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
        contentProviders = contentProviderFactory(inspector, application)

        // Create the invisible panel
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.alphaValue = 0
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.level = widgetLevel(0)
        panel.setIsVisible(true)
        maskPanel = panel

        panel.contentView = NSHostingView(
            rootView: ZStack {
                ForEach(0..<contentProviders.count, id: \.self) { (index: Int) in
                    self.contentProviders[index].contentBody
                }
            }
            .allowsHitTesting(false)
        )
        
        for contentProvider in contentProviders {
            if let window = contentProvider.createWindow() {
                panel.addChildWindow(window, ordered: .above)
            }
        }

        // Listen to AX notifications for window move/resize
        let windowElement = inspector.uiElement
        let stream = AXNotificationStream(
            app: application,
            element: windowElement,
            notificationNames: kAXMovedNotification, kAXResizedNotification
        )

        axNotificationTask = Task { [weak self] in
            for await notification in stream {
                guard let self else { return }
                switch notification.name {
                case kAXMovedNotification, kAXResizedNotification:
                    if let rect = windowElement.rect {
                        self.maskPanel.setFrame(rect, display: false)
                    }
                default: continue
                }
            }
        }

        if let rect = windowElement.rect {
            maskPanel.setFrame(rect, display: false)
        }
    }

    deinit {
        axNotificationTask?.cancel()
        _ = withExtendedLifetime(self) {
            Task { @MainActor in
                precondition(
                    !self.isDestroyed,
                    "IDEWorkspaceWindowOverlayWindowController should be destroyed before deinit"
                )
            }
        }
    }

    /// Make the window the top most window and visible.
    func access() {
        lastAccessDate = Date()
        maskPanel.level = widgetLevel(0)
        maskPanel.setIsVisible(true)
        maskPanel.orderFrontRegardless()
    }

    /// Stop keeping the window the top most window, do not change visibility.
    func dim() {
        maskPanel.level = .normal
    }

    /// Hide the window.
    func hide() {
        maskPanel.setIsVisible(false)
        maskPanel.level = .normal
    }

    /// Destroy the controller and clean up resources.
    func destroy() {
        axNotificationTask?.cancel()
        maskPanel.close()
        isDestroyed = true
    }
}

func widgetLevel(_ addition: Int) -> NSWindow.Level {
    let minimumWidgetLevel: Int
    #if DEBUG
    minimumWidgetLevel = NSWindow.Level.floating.rawValue + 1
    #else
    minimumWidgetLevel = NSWindow.Level.floating.rawValue
    #endif
    return .init(minimumWidgetLevel + addition)
}

