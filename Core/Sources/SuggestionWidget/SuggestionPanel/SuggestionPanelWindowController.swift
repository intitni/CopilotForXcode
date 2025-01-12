import AppKit
import Foundation
import SwiftUI

final class SuggestionPanelWindowController: NSWindowController {
    let suggestionPanel: SuggestionPanel
    var suggestionPanelWindow: SuggestionPanelWindow { window as! SuggestionPanelWindow }

    init() {
        suggestionPanel = .init()
        let window = SuggestionPanelWindow(suggestionPanel: suggestionPanel)
        super.init(window: window)
        window.delegate = self

        observe { [weak self] in
            guard let self else { return }
            self.suggestionPanelWindow.alphaValue = self.suggestionPanel.opacity
            self.suggestionPanelWindow.setFrame(
                self.suggestionPanel.frame,
                display: true,
                animate: false
            )
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        window?.close()
        window = nil
    }
}

extension SuggestionPanelWindowController: NSWindowDelegate {}

final class SuggestionPanelWindow: WidgetWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(suggestionPanel: SuggestionPanel) {
        super.init(
            contentRect: .init(x: 0, y: 0, width: Style.panelWidth, height: Style.panelHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        level = widgetLevel(2)
        hasShadow = true
        contentView = NSHostingView(rootView: SuggestionPanelView(store: suggestionPanel))

        setIsVisible(true)
    }
}

