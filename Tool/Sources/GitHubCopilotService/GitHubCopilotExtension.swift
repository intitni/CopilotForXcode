import BuiltinExtension
import CopilotForXcodeKit
import Foundation
import LanguageServerProtocol
import Logger
import Preferences
import Workspace

public final class GitHubCopilotExtension: BuiltinExtension {
    public var extensionIdentifier: String { "com.github.copilot" }
    
    public var suggestionServiceId: Preferences.BuiltInSuggestionFeatureProvider { .gitHubCopilot }

    public let suggestionService: GitHubCopilotSuggestionService
    public let chatService: GitHubCopilotChatService

    private var extensionUsage = ExtensionUsage(
        isSuggestionServiceInUse: false,
        isChatServiceInUse: false
    )
    private var isLanguageServerInUse: Bool {
        extensionUsage.isSuggestionServiceInUse || extensionUsage.isChatServiceInUse
    }

    let workspacePool: WorkspacePool

    let serviceLocator: ServiceLocatorType

    public init(workspacePool: WorkspacePool) {
        self.workspacePool = workspacePool
        serviceLocator = ServiceLocator(workspacePool: workspacePool)
        suggestionService = .init(serviceLocator: serviceLocator)
        chatService = .init(serviceLocator: serviceLocator)
    }

    public func workspaceDidOpen(_: WorkspaceInfo) {}

    public func workspaceDidClose(_: WorkspaceInfo) {}

    public func workspace(_ workspace: WorkspaceInfo, didOpenDocumentAt documentURL: URL) {
        guard isLanguageServerInUse else { return }
        // check if file size is larger than 15MB, if so, return immediately
        if let attrs = try? FileManager.default
            .attributesOfItem(atPath: documentURL.path),
            let fileSize = attrs[FileAttributeKey.size] as? UInt64,
            fileSize > 15 * 1024 * 1024
        { return }

        Task {
            do {
                let content = try String(contentsOf: documentURL, encoding: .utf8)
                guard let service = await serviceLocator.getService(from: workspace) else { return }
                try await service.notifyOpenTextDocument(fileURL: documentURL, content: content)
            } catch {
                Logger.gitHubCopilot.error(error.localizedDescription)
            }
        }
    }

    public func workspace(_ workspace: WorkspaceInfo, didSaveDocumentAt documentURL: URL) {
        guard isLanguageServerInUse else { return }
        Task {
            do {
                guard let service = await serviceLocator.getService(from: workspace) else { return }
                try await service.notifySaveTextDocument(fileURL: documentURL)
            } catch {
                Logger.gitHubCopilot.error(error.localizedDescription)
            }
        }
    }

    public func workspace(_ workspace: WorkspaceInfo, didCloseDocumentAt documentURL: URL) {
        guard isLanguageServerInUse else { return }
        Task {
            do {
                guard let service = await serviceLocator.getService(from: workspace) else { return }
                try await service.notifyCloseTextDocument(fileURL: documentURL)
            } catch {
                Logger.gitHubCopilot.error(error.localizedDescription)
            }
        }
    }

    public func workspace(
        _ workspace: WorkspaceInfo,
        didUpdateDocumentAt documentURL: URL,
        content: String?
    ) {
        guard isLanguageServerInUse else { return }
        // check if file size is larger than 15MB, if so, return immediately
        if let attrs = try? FileManager.default
            .attributesOfItem(atPath: documentURL.path),
            let fileSize = attrs[FileAttributeKey.size] as? UInt64,
            fileSize > 15 * 1024 * 1024
        { return }

        Task {
            guard let content else { return }
            guard let service = await serviceLocator.getService(from: workspace) else { return }
            do {
                try await service.notifyChangeTextDocument(
                    fileURL: documentURL,
                    content: content,
                    version: 0
                )
            } catch let error as ServerError {
                switch error {
                case .serverError(-32602, _, _): // parameter incorrect
                    Logger.gitHubCopilot.error(error.localizedDescription)
                    // Reopen document if it's not found in the language server
                    self.workspace(workspace, didOpenDocumentAt: documentURL)
                default:
                    Logger.gitHubCopilot.error(error.localizedDescription)
                }
            } catch {
                Logger.gitHubCopilot.error(error.localizedDescription)
            }
        }
    }

    public func extensionUsageDidChange(_ usage: ExtensionUsage) {
        extensionUsage = usage
        if !usage.isChatServiceInUse && !usage.isSuggestionServiceInUse {
            terminate()
        }
    }

    public func terminate() {
        for workspace in workspacePool.workspaces.values {
            guard let plugin = workspace.plugin(for: GitHubCopilotWorkspacePlugin.self)
            else { continue }
            plugin.terminate()
        }
    }
}

protocol ServiceLocatorType {
    func getService(from workspace: WorkspaceInfo) async -> GitHubCopilotService?
}

class ServiceLocator: ServiceLocatorType {
    let workspacePool: WorkspacePool

    
    init(workspacePool: WorkspacePool) {
        self.workspacePool = workspacePool
    }

    func getService(from workspace: WorkspaceInfo) async -> GitHubCopilotService? {
        guard let workspace = workspacePool.workspaces[workspace.workspaceURL],
              let plugin = workspace.plugin(for: GitHubCopilotWorkspacePlugin.self)
        else { return nil }
        return await plugin.gitHubCopilotService
    }
}

