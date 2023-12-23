import Dependencies
import Foundation
import SuggestionService
import Workspace
import WorkspaceSuggestionService
import XcodeInspector

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
    let globalShortcutManager: GlobalShortcutManager

    #if canImport(ProService)
    let proService: ProService
    #endif

    private init() {
        @Dependency(\.workspacePool) var workspacePool

        scheduledCleaner = .init()
        workspacePool.registerPlugin {
            SuggestionServiceWorkspacePlugin(workspace: $0) { projectRootURL, onLaunched in
                SuggestionService(projectRootURL: projectRootURL, onServiceLaunched: onLaunched)
            }
        }
        self.workspacePool = workspacePool
        globalShortcutManager = .init(guiController: guiController)

        #if canImport(ProService)
        proService = withDependencies { dependencyValues in
            dependencyValues.proServiceAcceptSuggestion = {
                Task { await PseudoCommandHandler().acceptSuggestion() }
            }
        } operation: {
            ProService()
        }
        #endif

        scheduledCleaner.service = self
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
        globalShortcutManager.start()
    }
}

