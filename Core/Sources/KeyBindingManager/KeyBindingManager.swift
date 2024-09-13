import Foundation
import Workspace


public final class KeyBindingManager {
    let tabToAcceptSuggestion: TabToAcceptSuggestion

    public init() {
        tabToAcceptSuggestion = .init()
    }
    
    public func start() {
        tabToAcceptSuggestion.start()
    }
    
    @MainActor
    public func stopForExit() {
        tabToAcceptSuggestion.stopForExit()
    }
}

    
