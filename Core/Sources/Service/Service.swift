import Foundation
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
    @WorkspaceActor
    public let realtimeSuggestionController = RealtimeSuggestionController()
    public let scheduledCleaner: ScheduledCleaner

    private init() {
        scheduledCleaner = .init(workspacePool: workspacePool, guiController: guiController)
        DependencyUpdater().update()
    }
}

