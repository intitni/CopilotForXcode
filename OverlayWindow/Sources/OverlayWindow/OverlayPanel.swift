import AppKit
import Perception
import SwiftUI

struct OverlayFrameEnvironmentKey: EnvironmentKey {
    static let defaultValue: CGRect = .zero
}

public extension EnvironmentValues {
    var overlayFrame: CGRect {
        get { self[OverlayFrameEnvironmentKey.self] }
        set { self[OverlayFrameEnvironmentKey.self] = newValue }
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
        @State var showOverlayArea: Bool = false

        var body: some View {
            WithPerceptionTracking {
                content()
                    .environment(\.overlayFrame, panelState.windowFrame)
                #if DEBUG
                    .background {
                        if showOverlayArea {
                            Rectangle().fill(.green.opacity(0.2))
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        HStack {
                            Button(action: {
                                showOverlayArea.toggle()
                            }) {
                                Image(systemName: "eye")
                                    .foregroundColor(showOverlayArea ? .green : .red)
                                    .padding()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                #endif
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

