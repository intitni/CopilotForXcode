import ActiveApplicationMonitor
import AppKit
import AsyncAlgorithms
import AXNotificationStream
import Combine
import ComposableArchitecture
import Environment
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

    private lazy var tabWindow = {
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
            rootView: TabView(store: store.scope(
                state: \.chatPanelState,
                action: WidgetFeature.Action.chatPanel
            ))
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
                if case .promptToCode = state.panelState.sharedPanelState.content {
                    return true
                }
                return false
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
            styleMask: [.resizable],
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.level = .init(NSWindow.Level.floating.rawValue + 1)
        it.collectionBehavior = [.fullScreenAuxiliary, .transient]
        it.hasShadow = true
        it.contentView = NSHostingView(
            rootView: ChatWindowView(
                store: store.scope(
                    state: \.chatPanelState,
                    action: WidgetFeature.Action.chatPanel
                )
            )
        )
        it.setIsVisible(true)
        it.delegate = self
        return it
    }()

    let store: StoreOf<WidgetFeature>
    let viewStore: ViewStoreOf<WidgetFeature>
    private var cancellable = Set<AnyCancellable>()

    public let dependency: SuggestionWidgetControllerDependency

    public init(
        store: StoreOf<WidgetFeature>,
        dependency: SuggestionWidgetControllerDependency
    ) {
        self.dependency = dependency
        self.store = store
        viewStore = .init(store, observe: { $0 })

        super.init()

        if ProcessInfo.processInfo.environment["IS_UNIT_TEST"] == "YES" { return }

        dependency.windows.chatPanelWindow = chatPanelWindow
        dependency.windows.tabWindow = tabWindow
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
        store.send(.panel(.discardPanelContent))
    }

    func markAsProcessing(_ isProcessing: Bool) {
        if isProcessing {
            store.send(.circularWidget(.markIsProcessing))
        } else {
            store.send(.circularWidget(.endIsProcessing))
        }
    }

    func presentError(_ errorDescription: String) {
        store.send(.panel(.presentError(errorDescription)))
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

    func presentPromptToCode() {
        store.send(.panel(.presentPromptToCode))
    }

    func discardPromptToCode() {
        store.send(.panel(.discardPanelContent))
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

    public func windowDidBecomeKey(_ notification: Notification) {
        guard (notification.object as? NSWindow) === chatPanelWindow else { return }
        let screenFrame = NSScreen.screens.first(where: { $0.frame.origin == .zero })?
            .frame ?? .zero
        var mouseLocation = NSEvent.mouseLocation
        let windowFrame = chatPanelWindow.frame
        if mouseLocation.y > windowFrame.maxY - 16,
           mouseLocation.y < windowFrame.maxY,
           mouseLocation.x > windowFrame.minX,
           mouseLocation.x < windowFrame.maxX
        {
            mouseLocation.y = screenFrame.size.height - mouseLocation.y
            if let cgEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseDown,
                mouseCursorPosition: mouseLocation,
                mouseButton: .left
            ),
                let event = NSEvent(cgEvent: cgEvent)
            {
                chatPanelWindow.performDrag(with: event)
            }
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

    override func mouseDown(with event: NSEvent) {
        let windowFrame = frame
        let currentLocation = event.locationInWindow
        if currentLocation.y > windowFrame.size.height - 16,
           currentLocation.y < windowFrame.size.height,
           currentLocation.x > 0,
           currentLocation.x < windowFrame.width
        {
            performDrag(with: event)
        }
    }
}

