import Foundation
import KeyBindingManager
import Workspace

@globalActor public enum ServiceActor {
    public actor TheActor {}
    public static let shared = TheActor()
}

/// The running extension service.
public final class Service {
    public static let shared = Service()

    @WorkspaceActor
    let workspacePool = {
        let it = WorkspacePool()
        it.registerPlugin {
            SuggestionServiceWorkspacePlugin(workspace: $0)
        }
        return it
    }()

    @MainActor
    public let guiController = GraphicalUserInterfaceController()
    public let realtimeSuggestionController = RealtimeSuggestionController()
    public let scheduledCleaner: ScheduledCleaner
    let keyBindingManager: KeyBindingManager

    private init() {
        scheduledCleaner = .init(workspacePool: workspacePool, guiController: guiController)
        keyBindingManager = .init(
            workspacePool: workspacePool,
            acceptSuggestion: {
                Task {
                    await PseudoCommandHandler().acceptSuggestion()
                }
            }
        )
    }
    
    @MainActor
    public func start() {
        scheduledCleaner.start()
        realtimeSuggestionController.start()
        guiController.start()
        keyBindingManager.start()
        DependencyUpdater().update()
    }
}

