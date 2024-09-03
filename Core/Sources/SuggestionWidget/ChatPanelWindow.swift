import AppKit
import ChatTab
import ComposableArchitecture
import Foundation
import SwiftUI

final class ChatPanelWindow: WidgetWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    private let storeObserver = NSObject()

    var minimizeWindow: () -> Void = {}

    override var defaultCollectionBehavior: NSWindow.CollectionBehavior {
        [
            .fullScreenAuxiliary,
            .transient,
            .fullScreenPrimary,
            .fullScreenAllowsTiling,
        ]
    }

    override var switchingSpaceCollectionBehavior: NSWindow.CollectionBehavior {
        [
            .fullScreenAuxiliary,
            .transient,
            .fullScreenPrimary,
            .fullScreenAllowsTiling,
        ]
    }
    
    override var fullscreenCollectionBehavior: NSWindow.CollectionBehavior {
        [
            .fullScreenAuxiliary,
            .transient,
            .fullScreenPrimary,
            .fullScreenAllowsTiling,
            .canJoinAllSpaces,
        ]
    }

    init(
        store: StoreOf<ChatPanel>,
        chatTabPool: ChatTabPool,
        minimizeWindow: @escaping () -> Void
    ) {
        self.minimizeWindow = minimizeWindow
        super.init(
            contentRect: .init(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.resizable, .titled, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        titleVisibility = .hidden
        addTitlebarAccessoryViewController({
            let controller = NSTitlebarAccessoryViewController()
            let view = NSHostingView(rootView: ChatTitleBar(store: store))
            controller.view = view
            view.frame = .init(x: 0, y: 0, width: 100, height: 40)
            controller.layoutAttribute = .right
            return controller
        }())
        titlebarAppearsTransparent = true
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        level = widgetLevel(1)

        hasShadow = true
        contentView = NSHostingView(
            rootView: ChatWindowView(
                store: store,
                toggleVisibility: { [weak self] isDisplayed in
                    guard let self else { return }
                    self.isPanelDisplayed = isDisplayed
                }
            )
            .environment(\.chatTabPool, chatTabPool)
        )
        setIsVisible(true)
        isPanelDisplayed = false

        var wasDetached = false
        storeObserver.observe { [weak self] in
            guard let self else { return }
            let isDetached = store.isDetached
            guard isDetached != wasDetached else { return }
            wasDetached = isDetached
            Task { @MainActor in
                if UserDefaults.shared.value(for: \.disableFloatOnTopWhenTheChatPanelIsDetached) {
                    self.setFloatOnTop(!isDetached)
                } else {
                    self.setFloatOnTop(true)
                }
            }
        }
    }
    
    func centerInActiveSpaceIfNeeded() {
        guard !isOnActiveSpace else { return }
        center()
    }

    func setFloatOnTop(_ isFloatOnTop: Bool) {
        let targetLevel: NSWindow.Level = isFloatOnTop
            ? .init(NSWindow.Level.floating.rawValue + 1)
            : .normal

        if targetLevel != level {
            level = targetLevel
        }
    }

    var isWindowHidden: Bool = false {
        didSet {
            alphaValue = isPanelDisplayed && !isWindowHidden ? 1 : 0
        }
    }

    var isPanelDisplayed: Bool = false {
        didSet {
            alphaValue = isPanelDisplayed && !isWindowHidden ? 1 : 0
        }
    }

    override var alphaValue: CGFloat {
        didSet {
            ignoresMouseEvents = alphaValue <= 0
        }
    }

    override func miniaturize(_: Any?) {
        minimizeWindow()
    }
}

