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
    private var activeAppChangeTask: Task<Void, Error>?

    nonisolated init(guiController: GraphicalUserInterfaceController) {
        self.guiController = guiController
    }

    func start() {
        KeyboardShortcuts.userDefaults = .shared
        setupShortcutIfNeeded()

        KeyboardShortcuts.onKeyUp(for: .showHideWidget) { [guiController] in
            let isXCodeActive = XcodeInspector.shared.activeXcode != nil

            if !isXCodeActive,
               !guiController.store.state.suggestionWidgetState.chatPanelState.isPanelDisplayed,
               UserDefaults.shared.value(for: \.showHideWidgetShortcutGlobally)
            {
                guiController.store.send(.openChatPanel(forceDetach: true, activateThisApp: true))
            } else {
                guiController.store.send(.toggleWidgetsHotkeyPressed)
            }
        }

        activeAppChangeTask?.cancel()
        activeAppChangeTask = Task.detached { [weak self] in
            let notifications = NotificationCenter.default
                .notifications(named: .activeApplicationDidChange)
            for await _ in notifications {
                guard let self else { return }
                try Task.checkCancellation()
                if !UserDefaults.shared.value(for: \.showHideWidgetShortcutGlobally) {
                    let app = await XcodeInspector.shared.activeApplication
                    let shouldBeEnabled = if let app, app.isXcode || app.isExtensionService {
                        true
                    } else {
                        false
                    }
                    if shouldBeEnabled {
                        await self.setupShortcutIfNeeded()
                    } else {
                        await self.removeShortcutIfNeeded()
                    }
                } else {
                    await self.setupShortcutIfNeeded()
                }
            }
        }
    }

    func setupShortcutIfNeeded() {
        KeyboardShortcuts.enable(.showHideWidget)
    }

    func removeShortcutIfNeeded() {
        KeyboardShortcuts.disable(.showHideWidget)
    }
}

