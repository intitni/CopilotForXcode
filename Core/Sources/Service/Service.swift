import Dependencies
import Foundation
import Workspace

#if canImport(KeyBindingManager)
import EnhancedWorkspace
import KeyBindingManager
#endif

@globalActor public enum ServiceActor {
    public actor TheActor {}
    public static let shared = TheActor()
}

/// The running extension service.
public final class Service {
    public static let shared = Service()

    @WorkspaceActor
    let workspacePool: WorkspacePool
    @MainActor
    public let guiController = GraphicalUserInterfaceController()
    public let realtimeSuggestionController = RealtimeSuggestionController()
    public let scheduledCleaner: ScheduledCleaner
    #if canImport(KeyBindingManager)
    let keyBindingManager: KeyBindingManager
    #endif

    private init() {
        @Dependency(\.workspacePool) var workspacePool
        
        scheduledCleaner = .init(workspacePool: workspacePool, guiController: guiController)
        #if canImport(KeyBindingManager)
        keyBindingManager = .init(
            workspacePool: workspacePool,
            acceptSuggestion: {
                Task {
                    await PseudoCommandHandler().acceptSuggestion()
                }
            }
        )
        #endif

        workspacePool.registerPlugin { SuggestionServiceWorkspacePlugin(workspace: $0) }
        #if canImport(EnhancedWorkspace)
        workspacePool.registerPlugin { EnhancedWorkspacePlugin(workspace: $0) }
        #endif
        
        self.workspacePool = workspacePool
    }

    @MainActor
    public func start() {
        scheduledCleaner.start()
        realtimeSuggestionController.start()
        guiController.start()
        #if canImport(KeyBindingManager)
        keyBindingManager.start()
        #endif
        DependencyUpdater().update()
    }
}

