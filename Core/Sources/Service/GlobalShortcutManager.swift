import AppKit
import Combine
import Foundation
import KeyboardShortcuts
import XcodeInspector

extension KeyboardShortcuts.Name {
    static let showHideWidget = Self("ShowHideWidget")
}

@MainActor
final class GlobalShortcutManager {
    let guiController: GraphicalUserInterfaceController
    private var cancellable = Set<AnyCancellable>()

    nonisolated init(guiController: GraphicalUserInterfaceController) {
        self.guiController = guiController
    }

    func start() {
        KeyboardShortcuts.userDefaults = .shared
        setupShortcutIfNeeded()

        KeyboardShortcuts.onKeyUp(for: .showHideWidget) { [guiController] in
            let isXCodeActive = XcodeInspector.shared.activeXcode != nil
            let isExtensionActive = NSApplication.shared.isActive

            if !isXCodeActive,
               !guiController.viewStore.state.suggestionWidgetState.chatPanelState.isPanelDisplayed,
               UserDefaults.shared.value(for: \.showHideWidgetShortcutGlobally)
            {
                guiController.viewStore.send(.openChatPanel(forceDetach: true))
            } else {
                guiController.viewStore.send(.toggleWidgets)
            }

            if !isExtensionActive {
                Task {
                    try await Task.sleep(nanoseconds: 150_000_000)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
            } else if let previous = XcodeInspector.shared.previousActiveApplication,
                      !previous.isActive
            {
                previous.runningApplication.activate()
            }
        }

        XcodeInspector.shared.$activeApplication.sink { app in
            if !UserDefaults.shared.value(for: \.showHideWidgetShortcutGlobally) {
                let shouldBeEnabled = if let app, app.isXcode || app.isExtensionService {
                    true
                } else {
                    false
                }
                if shouldBeEnabled {
                    self.setupShortcutIfNeeded()
                } else {
                    self.removeShortcutIfNeeded()
                }
            } else {
                self.setupShortcutIfNeeded()
            }
        }.store(in: &cancellable)
    }

    func setupShortcutIfNeeded() {
        KeyboardShortcuts.enable(.showHideWidget)
    }

    func removeShortcutIfNeeded() {
        KeyboardShortcuts.disable(.showHideWidget)
    }
}

