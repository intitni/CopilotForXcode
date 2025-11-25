import AppKit
import Perception
import SwiftUI

struct OverlayFrameEnvironmentKey: EnvironmentKey {
    static let defaultValue: CGRect = .zero
}

struct OverlayDebugEnvironmentKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

public extension EnvironmentValues {
    var overlayFrame: CGRect {
        get { self[OverlayFrameEnvironmentKey.self] }
        set { self[OverlayFrameEnvironmentKey.self] = newValue }
    }

    var overlayDebug: Bool {
        get { self[OverlayDebugEnvironmentKey.self] }
        set { self[OverlayDebugEnvironmentKey.self] = newValue }
    }
}

@MainActor
final class OverlayPanel: NSPanel {
    @MainActor
    @Perceptible
    final class PanelState {
        var windowFrame: CGRect = .zero
        var windowFrameNSCoordinate: CGRect = .zero
    }

    let panelState: PanelState = .init()

    init<Content: View>(
        contentRect: NSRect,
        @ViewBuilder content: @escaping () -> Content
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [
                .borderless,
                .nonactivatingPanel,
                .fullSizeContentView,
            ],
            backing: .buffered,
            defer: false
        )

        isReleasedWhenClosed = false
        menu = nil
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        alphaValue = 1.0
        collectionBehavior = [.fullScreenAuxiliary]
        isFloatingPanel = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        animationBehavior = .utilityWindow

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        contentView = NSHostingView(
            rootView: ContentWrapper(panelState: panelState) { content() }
        )
    }

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return false
    }

    func moveToActiveSpace() {
        collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        Task { @MainActor in
            try await Task.sleep(nanoseconds: 50_000_000)
            self.collectionBehavior = [.fullScreenAuxiliary]
        }
    }

    func setTopLeftCoordinateFrame(_ frame: CGRect, display: Bool) {
        let screen = NSScreen.screens
            .first(where: { $0.frame.intersects(frame) }) ?? NSScreen.main
        let panelFrame = Self.convertAXRectToNSPanelFrame(
            axRect: frame,
            forScreen: screen
        )
        panelState.windowFrame = frame
        panelState.windowFrameNSCoordinate = panelFrame
        setFrame(panelFrame, display: display)
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

    struct ContentWrapper<Content: View>: View {
        let panelState: PanelState
        @ViewBuilder let content: () -> Content
        @AppStorage(\.debugOverlayPanel) var debugOverlayPanel

        var body: some View {
            WithPerceptionTracking {
                ZStack {
                    Rectangle().fill(.green.opacity(debugOverlayPanel ? 0.1 : 0))
                        .allowsHitTesting(false)
                    content()
                        .environment(\.overlayFrame, panelState.windowFrame)
                        .environment(\.overlayDebug, debugOverlayPanel)
                }
            }
        }
    }
}

func overlayLevel(_ addition: Int) -> NSWindow.Level {
    let minimumWidgetLevel: Int
    #if DEBUG
    minimumWidgetLevel = NSWindow.Level.floating.rawValue + 1
    #else
    minimumWidgetLevel = NSWindow.Level.floating.rawValue
    #endif
    return .init(minimumWidgetLevel + addition)
}

