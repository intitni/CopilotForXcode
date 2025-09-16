import BuiltinExtension
import CodeiumService
import Combine
import CommandHandler
import Dependencies
import Foundation
import GitHubCopilotService
import KeyBindingManager
import Logger
import SuggestionService
import Toast
import Workspace
import WorkspaceSuggestionService
import XcodeInspector
import XcodeThemeController
import XPCShared
#if canImport(ProService)
import ProService
#endif

@globalActor public enum ServiceActor {
    public actor TheActor {}
    public static let shared = TheActor()
}

/// The running extension service.
public final class Service {
    @MainActor
    public static let shared = Service()

    @Dependency(\.workspacePool) var workspacePool
    @MainActor
    public let guiController: GraphicalUserInterfaceController
    public let commandHandler: CommandHandler
    public let realtimeSuggestionController: RealtimeSuggestionController
    public let scheduledCleaner: ScheduledCleaner
    let globalShortcutManager: GlobalShortcutManager
    let keyBindingManager: KeyBindingManager
    let xcodeThemeController: XcodeThemeController = .init()

    #if canImport(ProService)
    let proService: ProService
    #endif

    @Dependency(\.toast) var toast
    var cancellable = Set<AnyCancellable>()

    @MainActor
    private init() {
        @Dependency(\.workspacePool) var workspacePool
        let commandHandler = PseudoCommandHandler()
        UniversalCommandHandler.shared.commandHandler = commandHandler
        self.commandHandler = commandHandler

        realtimeSuggestionController = .init()
        scheduledCleaner = .init()

        #if canImport(ProService)
        proService = ProService()
        #endif

        BuiltinExtensionManager.shared.addExtensions([
            GitHubCopilotExtension(workspacePool: workspacePool),
            CodeiumExtension(workspacePool: workspacePool),
        ])

        let guiController = GraphicalUserInterfaceController()
        self.guiController = guiController
        globalShortcutManager = .init(guiController: guiController)
        keyBindingManager = .init()

        workspacePool.registerPlugin {
            SuggestionServiceWorkspacePlugin(workspace: $0) { SuggestionService.service() }
        }
        workspacePool.registerPlugin {
            GitHubCopilotWorkspacePlugin(workspace: $0)
        }
        workspacePool.registerPlugin {
            CodeiumWorkspacePlugin(workspace: $0)
        }
        workspacePool.registerPlugin {
            BuiltinExtensionWorkspacePlugin(workspace: $0)
        }

        scheduledCleaner.service = self
    }

    @MainActor
    public func start() {
        scheduledCleaner.start()
        realtimeSuggestionController.start()
        guiController.start()
        xcodeThemeController.start()
        #if canImport(ProService)
        proService.start()
        #endif
        DependencyUpdater().update()
        globalShortcutManager.start()
        keyBindingManager.start()

        Task.detached { [weak self] in
            let notifications = NotificationCenter.default
                .notifications(named: .activeDocumentURLDidChange)
            var previousURL: URL?
            for await _ in notifications {
                guard let self else { return }
                let url = await XcodeInspector.shared.activeDocumentURL
                if let url, url != previousURL, url != .init(fileURLWithPath: "/") {
                    previousURL = url
                    @Dependency(\.workspacePool) var workspacePool
                    _ = try await workspacePool
                        .fetchOrCreateWorkspaceAndFilespace(fileURL: url)
                }
            }
        }
    }

    @MainActor
    public func prepareForExit() async {
        Logger.service.info("Prepare for exit.")
        keyBindingManager.stopForExit()
        #if canImport(ProService)
        proService.prepareForExit()
        #endif
        await scheduledCleaner.closeAllChildProcesses()
    }
}

public extension Service {
    func handleXPCServiceRequests(
        endpoint: String,
        requestBody: Data,
        reply: @escaping (Data?, Error?) -> Void
    ) {
        do {
            #if canImport(ProService)
            try proService.handleXPCServiceRequests(
                endpoint: endpoint,
                requestBody: requestBody,
                reply: reply
            )
            #endif

            try ExtensionServiceRequests.GetExtensionOpenChatHandlers.handle(
                endpoint: endpoint,
                requestBody: requestBody,
                reply: reply
            ) { _ in
                BuiltinExtensionManager.shared.extensions.reduce(into: []) { result, ext in
                    let tabs = ext.chatTabTypes
                    for tab in tabs {
                        if tab.canHandleOpenChatCommand {
                            result.append(.init(
                                bundleIdentifier: ext.extensionIdentifier,
                                id: tab.name,
                                tabName: tab.name,
                                isBuiltIn: true
                            ))
                        }
                    }
                }
            }

            try ExtensionServiceRequests.GetSuggestionLineAcceptedCode.handle(
                endpoint: endpoint,
                requestBody: requestBody,
                reply: reply
            ) { request in
                let editor = request.editorContent
                let handler = WindowBaseCommandHandler()
                let updatedContent = try? await handler
                    .acceptSuggestionLine(editor: editor)
                return updatedContent
            }
        } catch is XPCRequestHandlerHitError {
            return
        } catch {
            reply(nil, error)
            return
        }

        reply(nil, XPCRequestNotHandledError())
    }
}

