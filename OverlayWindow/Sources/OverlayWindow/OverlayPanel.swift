import AppKit
import SwiftUI

@MainActor
final class OverlayPanel<Content: View>: NSPanel {
    init(
        contentRect: NSRect,
        @ViewBuilder content: () -> Content
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
            rootView: content()
        )
    }

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return false
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
