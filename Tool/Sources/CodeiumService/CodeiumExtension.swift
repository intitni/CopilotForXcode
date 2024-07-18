import BuiltinExtension
import ChatTab
import CopilotForXcodeKit
import Foundation
import Logger
import Preferences
import Workspace

@globalActor public enum CodeiumActor {
    public actor TheActor {}
    public static let shared = TheActor()
}

public final class CodeiumExtension: BuiltinExtension {
    public var extensionIdentifier: String { "com.codeium" }
    
    public var suggestionServiceId: Preferences.BuiltInSuggestionFeatureProvider { .codeium }

    public let suggestionService: CodeiumSuggestionService
    
    public var chatTabTypes: [any ChatTab.Type] {
        [CodeiumChatTab.self]
    }

    private var extensionUsage = ExtensionUsage(
        isSuggestionServiceInUse: false,
        isChatServiceInUse: false
    )
    private var isLanguageServerInUse: Bool {
        get async {
            let lifeKeeperIsAlive = await CodeiumServiceLifeKeeper.shared.isAlive
            return extensionUsage.isSuggestionServiceInUse
                || extensionUsage.isChatServiceInUse
                || lifeKeeperIsAlive
        }
    }

    let workspacePool: WorkspacePool

    let serviceLocator: ServiceLocator

    public init(workspacePool: WorkspacePool) {
        self.workspacePool = workspacePool
        serviceLocator = .init(workspacePool: workspacePool)
        suggestionService = .init(serviceLocator: serviceLocator)
    }

    public func workspaceDidOpen(_ workspace: WorkspaceInfo) {
        Task {
            do {
                guard await isLanguageServerInUse else { return }
                guard let service = await serviceLocator.getService(from: workspace) else { return }
                try await service.notifyOpenWorkspace(workspaceURL: workspace.workspaceURL)
            } catch {
                Logger.codeium.error(error.localizedDescription)
            }
        }
    }

    public func workspaceDidClose(_ workspace: WorkspaceInfo) {
        Task {
            do {
                guard await isLanguageServerInUse else { return }
                guard let service = await serviceLocator.getService(from: workspace) else { return }
                try await service.notifyCloseWorkspace(workspaceURL: workspace.workspaceURL)
            } catch {
                Logger.codeium.error(error.localizedDescription)
            }
        }
    }

    public func workspace(_ workspace: WorkspaceInfo, didOpenDocumentAt documentURL: URL) {
        Task {
            guard await isLanguageServerInUse else { return }
            // check if file size is larger than 15MB, if so, return immediately
            if let attrs = try? FileManager.default
                .attributesOfItem(atPath: documentURL.path),
                let fileSize = attrs[FileAttributeKey.size] as? UInt64,
                fileSize > 15 * 1024 * 1024
            { return }

            do {
                let content = try String(contentsOf: documentURL, encoding: .utf8)
                guard let service = await serviceLocator.getService(from: workspace) else { return }
                try await service.notifyOpenTextDocument(fileURL: documentURL, content: content)
            } catch {
                Logger.codeium.error(error.localizedDescription)
            }
        }
    }

    public func workspace(_ workspace: WorkspaceInfo, didSaveDocumentAt documentURL: URL) {
        // unimplemented
    }

    public func workspace(_ workspace: WorkspaceInfo, didCloseDocumentAt documentURL: URL) {
        Task {
            guard await isLanguageServerInUse else { return }
            do {
                guard let service = await serviceLocator.getService(from: workspace) else { return }
                try await service.notifyCloseTextDocument(fileURL: documentURL)
            } catch {
                Logger.codeium.error(error.localizedDescription)
            }
        }
    }

    public func workspace(
        _ workspace: WorkspaceInfo,
        didUpdateDocumentAt documentURL: URL,
        content: String?
    ) {
        Task {
            guard await isLanguageServerInUse else { return }
            // check if file size is larger than 15MB, if so, return immediately
            if let attrs = try? FileManager.default
                .attributesOfItem(atPath: documentURL.path),
                let fileSize = attrs[FileAttributeKey.size] as? UInt64,
                fileSize > 15 * 1024 * 1024
            { return }
            do {
                guard let content else { return }
                guard let service = await serviceLocator.getService(from: workspace) else { return }
                try await service.notifyChangeTextDocument(fileURL: documentURL, content: content)
                try await service.refreshIDEContext(
                    fileURL: documentURL,
                    content: content,
                    cursorPosition: .zero,
                    tabSize: 4, indentSize: 4, usesTabsForIndentation: false,
                    workspaceURL: workspace.workspaceURL
                )
            } catch {
                Logger.codeium.error(error.localizedDescription)
            }
        }
    }

    public func extensionUsageDidChange(_ usage: ExtensionUsage) {
        extensionUsage = usage
        Task {
            if !(await isLanguageServerInUse) {
                terminate()
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
        return await plugin.codeiumService
    }
}

/// A helper class to keep track of a list of items that may keep the service alive.
/// For example, a ``CodeiumChatTab``.
actor CodeiumServiceLifeKeeper {
    static let shared = CodeiumServiceLifeKeeper()

    private final class WeakObject {
        weak var object: AnyObject?
        var isAlive: Bool { object != nil }
        init(_ object: AnyObject) {
            self.object = object
        }
    }

    private var weakObjects = [WeakObject]()

    func add(_ object: AnyObject) {
        weakObjects.removeAll { !$0.isAlive }
        weakObjects.append(WeakObject(object))
    }

    var isAlive: Bool {
        if weakObjects.isEmpty { return false }
        return weakObjects.allSatisfy { $0.isAlive }
    }
}

