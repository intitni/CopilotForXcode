import Foundation
import Workspace

public final class KeyBindingManager {
    let keybindingController: KeyBindingController

    public init() {
        keybindingController = .init()
    }

    public func start() {
        keybindingController.start()
    }

    @MainActor
    public func stopForExit() {
        keybindingController.stopForExit()
    }
}

