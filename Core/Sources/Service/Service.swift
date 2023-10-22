import Combine
import Dependencies
import Foundation
import KeyboardShortcuts
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

extension KeyboardShortcuts.Name {
    static let showHideWidget = Self("ShowHideWidget")
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

        scheduledCleaner = .init(workspacePool: workspacePool, guiController: guiController)
        workspacePool.registerPlugin { SuggestionServiceWorkspacePlugin(workspace: $0) }
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
            guiController.viewStore.send(.suggestionWidget(.circularWidget(.widgetClicked)))
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

