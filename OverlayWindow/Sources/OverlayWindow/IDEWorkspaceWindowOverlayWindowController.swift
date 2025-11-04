import AppKit
import AXExtension
import AXNotificationStream
import Foundation
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
        let contentProviders = contentProviderFactory(inspector, application)
        self.contentProviders = contentProviders

        let panel = OverlayPanel(
            contentRect: .init(x: 0, y: 0, width: 200, height: 200)
        ) {
            ContentWrapper {
                ZStack {
                    ForEach(0..<contentProviders.count, id: \.self) { index in
                        contentProviders[index].contentBody
                    }
                }
            }
        }
        maskPanel = panel

        for contentProvider in contentProviders {
            if let window = contentProvider.createWindow() {
                panel.addChildWindow(window, ordered: .above)
            }
        }

        let windowElement = inspector.uiElement
        let stream = AXNotificationStream(
            app: application,
            element: windowElement,
            notificationNames: kAXMovedNotification, kAXResizedNotification
        )

        axNotificationTask = Task { [weak panel] in
            for await notification in stream {
                guard let panel else { return }
                if Task.isCancelled { return }
                switch notification.name {
                case kAXMovedNotification, kAXResizedNotification:
                    if let rect = windowElement.rect {
                        let screen = NSScreen.screens
                            .first(where: { $0.frame.intersects(rect) }) ?? NSScreen.main
                        let panelFrame = Self.convertAXRectToNSPanelFrame(
                            axRect: rect,
                            forScreen: screen
                        )
                        panel.setFrame(panelFrame, display: false)
                    }
                default: continue
                }
            }
        }

        if let rect = windowElement.rect {
            let screen = NSScreen.screens.first(where: { $0.frame.intersects(rect) }) ?? NSScreen
                .main
            let panelFrame = Self.convertAXRectToNSPanelFrame(axRect: rect, forScreen: screen)
            panel.setFrame(panelFrame, display: false)
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

    func access() {
        lastAccessDate = Date()
        maskPanel.level = overlayLevel(0)
        maskPanel.setIsVisible(true)
        maskPanel.orderFrontRegardless()
    }

    func dim() {
        maskPanel.level = .normal
    }

    func hide() {
        maskPanel.setIsVisible(false)
        maskPanel.level = .normal
    }

    func destroy() {
        axNotificationTask?.cancel()
        maskPanel.close()
        for contentProvider in contentProviders {
            contentProvider.destroy()
        }
        isDestroyed = true
    }
}

extension IDEWorkspaceWindowOverlayWindowController {
    struct ContentWrapper<Content: View>: View {
        @ViewBuilder let content: () -> Content
        @State var showOverlayArea: Bool = false

        var body: some View {
            content()
                .background {
                    if showOverlayArea {
                        Rectangle().fill(.green.opacity(0.2))
                    }
                }
                .overlay(alignment: .topTrailing) {
                    #if DEBUG
                    HStack {
                        Button(action: {
                            showOverlayArea.toggle()
                        }) {
                            Image(systemName: "eye")
                                .foregroundColor(showOverlayArea ? .green : .red)
                        }
                        .padding()
                    }
                    #else
                    EmptyView()
                    #endif
                }
        }
    }

    static func convertAXRectToNSPanelFrame(axRect: CGRect, forScreen screen: NSScreen?) -> CGRect {
        guard let screen = screen else { return .zero }
        let screenFrame = screen.frame
        let flippedY = screenFrame.origin.y + screenFrame.size
            .height - (axRect.origin.y + axRect.size.height)
        return CGRect(
            x: axRect.origin.x,
            y: flippedY,
            width: axRect.size.width,
            height: axRect.size.height
        )
    }
}

