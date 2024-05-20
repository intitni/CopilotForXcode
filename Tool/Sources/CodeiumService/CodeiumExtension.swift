import CopilotForXcodeKit
import Foundation
import Workspace
import Logger
import BuiltinExtension

public final class CodeiumExtension: BuiltinExtension {
    public var suggestionService: SuggestionServiceType? { _suggestionService }
    public var chatService: ChatServiceType? { nil }
    public var promptToCodeService: PromptToCodeServiceType? { nil }
    let workspacePool: WorkspacePool

    let serviceLocator: ServiceLocator
    let _suggestionService: CodeiumSuggestionService

    public init(workspacePool: WorkspacePool) {
        self.workspacePool = workspacePool
        serviceLocator = .init(workspacePool: workspacePool)
        _suggestionService = .init(serviceLocator: serviceLocator)
    }

    public func workspaceDidOpen(_: WorkspaceInfo) {}

    public func workspaceDidClose(_: WorkspaceInfo) {}

    public func workspace(_ workspace: WorkspaceInfo, didOpenDocumentAt documentURL: URL) {
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
        // unimplemented
    }

    public func workspace(_ workspace: WorkspaceInfo, didCloseDocumentAt documentURL: URL) {
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
        content: String
    ) {
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

    public func appConfigurationDidChange(_ configuration: AppConfiguration) {
        if !configuration.chatServiceInUse && !configuration.suggestionServiceInUse {
            for workspace in workspacePool.workspaces.values {
                guard let plugin = workspace.plugin(for: CodeiumWorkspacePlugin.self)
                else { continue }
                plugin.terminate()
            }
        }
    }
    
    public func terminate() {
        for workspace in workspacePool.workspaces.values {
            guard let plugin = workspace.plugin(for: CodeiumWorkspacePlugin.self)
            else { continue }
            plugin.terminate()
        }
    }
}

final class ServiceLocator {
    let workspacePool: WorkspacePool

    init(workspacePool: WorkspacePool) {
        self.workspacePool = workspacePool
    }

    func getService(from workspace: WorkspaceInfo) async -> CodeiumService? {
        guard let workspace = workspacePool.workspaces[workspace.workspaceURL],
              let plugin = workspace.plugin(for: CodeiumWorkspacePlugin.self)
        else { return nil }
        return plugin.codeiumService
    }
}

