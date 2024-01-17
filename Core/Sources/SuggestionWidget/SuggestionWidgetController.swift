import ActiveApplicationMonitor
import AppKit
import AsyncAlgorithms
import AXNotificationStream
import ChatTab
import Combine
import ComposableArchitecture
import Preferences
import SwiftUI
import UserDefaultsObserver
import XcodeInspector

@MainActor
public final class SuggestionWidgetController: NSObject {
    // you should make these window `.transient` so they never show up in the mission control.

    private lazy var fullscreenDetector = {
        let it = CanBecomeKeyWindow(
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
        it.canBecomeKeyChecker = { false }
        return it
    }()

    private lazy var widgetWindow = {
        let it = CanBecomeKeyWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.level = .floating
        it.collectionBehavior = [.fullScreenAuxiliary, .transient]
        it.hasShadow = true
        it.contentView = NSHostingView(
            rootView: WidgetView(
                store: store.scope(
                    state: \._circularWidgetState,
                    action: WidgetFeature.Action.circularWidget
                )
            )
        )
        it.setIsVisible(true)
        it.canBecomeKeyChecker = { false }
        return it
    }()

    private lazy var sharedPanelWindow = {
        let it = CanBecomeKeyWindow(
            contentRect: .init(x: 0, y: 0, width: Style.panelWidth, height: Style.panelHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.level = .init(NSWindow.Level.floating.rawValue + 2)
        it.collectionBehavior = [.fullScreenAuxiliary, .transient]
        it.hasShadow = true
        it.contentView = NSHostingView(
            rootView: SharedPanelView(
                store: store.scope(
                    state: \.panelState,
                    action: WidgetFeature.Action.panel
                ).scope(
                    state: \.sharedPanelState,
                    action: PanelFeature.Action.sharedPanel
                )
            )
        )
        it.setIsVisible(true)
        it.canBecomeKeyChecker = { [store] in
            store.withState { state in
                state.panelState.sharedPanelState.content.promptToCode != nil
            }
        }
        return it
    }()

    private lazy var suggestionPanelWindow = {
        let it = CanBecomeKeyWindow(
            contentRect: .init(x: 0, y: 0, width: Style.panelWidth, height: Style.panelHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.level = .init(NSWindow.Level.floating.rawValue + 2)
        it.collectionBehavior = [.fullScreenAuxiliary, .transient]
        it.hasShadow = true
        it.contentView = NSHostingView(
            rootView: SuggestionPanelView(
                store: store.scope(
                    state: \.panelState,
                    action: WidgetFeature.Action.panel
                ).scope(
                    state: \.suggestionPanelState,
                    action: PanelFeature.Action.suggestionPanel
                )
            )
        )
        it.canBecomeKeyChecker = { false }
        it.setIsVisible(true)
        return it
    }()

    private lazy var chatPanelWindow = {
        let it = ChatWindow(
            contentRect: .zero,
            styleMask: [.resizable, .titled, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        it.minimizeWindow = { [weak self] in
            self?.store.send(.chatPanel(.hideButtonClicked))
        }
        it.titleVisibility = .hidden
        it.addTitlebarAccessoryViewController({
            let controller = NSTitlebarAccessoryViewController()
            let view = NSHostingView(rootView: ChatTitleBar(store: store.scope(
                state: \.chatPanelState,
                action: WidgetFeature.Action.chatPanel
            )))
            controller.view = view
            view.frame = .init(x: 0, y: 0, width: 100, height: 40)
            controller.layoutAttribute = .left
            return controller
        }())
        it.titlebarAppearsTransparent = true
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.level = .init(NSWindow.Level.floating.rawValue + 1)
        it.collectionBehavior = [
            .fullScreenAuxiliary,
            .transient,
            .fullScreenPrimary,
            .fullScreenAllowsTiling,
        ]
        it.hasShadow = true
        it.contentView = NSHostingView(
            rootView: ChatWindowView(
                store: store.scope(
                    state: \.chatPanelState,
                    action: WidgetFeature.Action.chatPanel
                ),
                toggleVisibility: { [weak it] isDisplayed in
                    guard let window = it else { return }
                    window.isPanelDisplayed = isDisplayed
                }
            )
            .environment(\.chatTabPool, chatTabPool)
        )
        it.setIsVisible(true)
        it.isPanelDisplayed = false
        it.delegate = self
        return it
    }()

    private lazy var toastWindow = {
        let it = CanBecomeKeyWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = true
        it.backgroundColor = .clear
        it.level = .floating
        it.collectionBehavior = [.fullScreenAuxiliary, .transient]
        it.hasShadow = false
        it.contentView = NSHostingView(
            rootView: ToastPanelView(store: store.scope(
                state: \.toastPanel,
                action: WidgetFeature.Action.toastPanel
            ))
        )
        it.setIsVisible(true)
        it.ignoresMouseEvents = true
        it.canBecomeKeyChecker = { false }
        return it
    }()

    let store: StoreOf<WidgetFeature>
    let viewStore: ViewStoreOf<WidgetFeature>
    let chatTabPool: ChatTabPool
    private var cancellable = Set<AnyCancellable>()

    public let dependency: SuggestionWidgetControllerDependency

    public init(
        store: StoreOf<WidgetFeature>,
        chatTabPool: ChatTabPool,
        dependency: SuggestionWidgetControllerDependency
    ) {
        self.dependency = dependency
        self.store = store
        self.chatTabPool = chatTabPool
        viewStore = .init(store, observe: { $0 })

        super.init()

        if ProcessInfo.processInfo.environment["IS_UNIT_TEST"] == "YES" { return }

        dependency.windows.chatPanelWindow = chatPanelWindow
        dependency.windows.toastWindow = toastWindow
        dependency.windows.sharedPanelWindow = sharedPanelWindow
        dependency.windows.suggestionPanelWindow = suggestionPanelWindow
        dependency.windows.fullscreenDetector = fullscreenDetector
        dependency.windows.widgetWindow = widgetWindow

        store.send(.startup)
    }
}

// MARK: - Handle Events

public extension SuggestionWidgetController {
    func suggestCode() {
        store.send(.panel(.presentSuggestion))
    }

    func discardSuggestion() {
        store.send(.panel(.discardSuggestion))
    }

    func markAsProcessing(_ isProcessing: Bool) {
        if isProcessing {
            store.send(.circularWidget(.markIsProcessing))
        } else {
            store.send(.circularWidget(.endIsProcessing))
        }
    }

    func presentError(_ errorDescription: String) {
        store.send(.toastPanel(.toast(.toast(errorDescription, .error))))
    }

    func presentChatRoom() {
        store.send(.chatPanel(.presentChatPanel(forceDetach: false)))
    }

    func presentDetachedGlobalChat() {
        store.send(.chatPanel(.presentChatPanel(forceDetach: true)))
    }

    func closeChatRoom() {
//        store.send(.chatPanel(.closeChatPanel))
    }
}

// MARK: - NSWindowDelegate

extension SuggestionWidgetController: NSWindowDelegate {
    public func windowWillMove(_ notification: Notification) {
        guard (notification.object as? NSWindow) === chatPanelWindow else { return }
        Task { @MainActor in
            await Task.yield()
            store.send(.chatPanel(.detachChatPanel))
        }
    }
}

// MARK: - Window Subclasses

class CanBecomeKeyWindow: NSWindow {
    var canBecomeKeyChecker: () -> Bool = { true }
    override var canBecomeKey: Bool { canBecomeKeyChecker() }
    override var canBecomeMain: Bool { canBecomeKeyChecker() }
}

class ChatWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    var minimizeWindow: () -> Void = {}

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

