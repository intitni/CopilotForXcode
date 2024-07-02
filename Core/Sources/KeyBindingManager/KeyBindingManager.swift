import Foundation
import Workspace

public final class KeyBindingManager {
    let tabToAcceptSuggestion: TabToAcceptSuggestion

    public init(
        workspacePool: WorkspacePool,
        acceptSuggestion: @escaping () -> Void,
        dismissSuggestion: @escaping () -> Void
    ) {
        tabToAcceptSuggestion = .init(
            workspacePool: workspacePool,
            acceptSuggestion: acceptSuggestion, 
            dismissSuggestion: dismissSuggestion
        )
    }
    
    public func start() {
        tabToAcceptSuggestion.start()
    }
    
    @MainActor
    public func stopForExit() {
        tabToAcceptSuggestion.stopForExit()
    }
}

    
