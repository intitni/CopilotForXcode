import Dependencies
import Foundation
import Workspace
import WorkspaceSuggestionService

#if canImport(ProService)
import ProService
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

    #if canImport(ProService)
    let proService: ProService
    #endif

    private init() {
        @Dependency(\.workspacePool) var workspacePool

        scheduledCleaner = .init(workspacePool: workspacePool, guiController: guiController)
        workspacePool.registerPlugin { SuggestionServiceWorkspacePlugin(workspace: $0) }
        self.workspacePool = workspacePool

        #if canImport(ProService)
        proService = withDependencies { dependencyValues in
            dependencyValues.proServiceAcceptSuggestion = {
                Task { await PseudoCommandHandler().acceptSuggestion() }
            }
        } operation: {
            ProService()
        }
        #endif
    }

    @MainActor
    public func start() {
        scheduledCleaner.start()
        realtimeSuggestionController.start()
        guiController.start()
        #if canImport(ProService)
        proService.start()
        #endif
        DependencyUpdater().update()
    }
}

