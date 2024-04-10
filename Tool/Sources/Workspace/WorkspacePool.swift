import Dependencies
import Foundation
import XcodeInspector

public struct WorkspacePoolDependencyKey: DependencyKey {
    public static var liveValue: WorkspacePool = .init()
}

public extension DependencyValues {
    var workspacePool: WorkspacePool {
        get { self[WorkspacePoolDependencyKey.self] }
        set { self[WorkspacePoolDependencyKey.self] = newValue }
    }
}

@globalActor public enum WorkspaceActor {
    public actor TheActor {}
    public static let shared = TheActor()
}

public class WorkspacePool {
    public enum Error: Swift.Error, LocalizedError {
        case invalidWorkspaceURL(URL)

        public var errorDescription: String? {
            switch self {
            case let .invalidWorkspaceURL(url):
                return "Invalid workspace URL: \(url)"
            }
        }
    }

    public internal(set) var workspaces: [URL: Workspace] = [:]
    var plugins = [ObjectIdentifier: (Workspace) -> WorkspacePlugin]()

    public init(
        workspaces: [URL: Workspace] = [:],
        plugins: [ObjectIdentifier: (Workspace) -> WorkspacePlugin] = [:]
    ) {
        self.workspaces = workspaces
        self.plugins = plugins
    }

    public func registerPlugin<Plugin: WorkspacePlugin>(_ plugin: @escaping (Workspace) -> Plugin) {
        let id = ObjectIdentifier(Plugin.self)
        let erasedPlugin: (Workspace) -> WorkspacePlugin = { plugin($0) }
        plugins[id] = erasedPlugin

        for workspace in workspaces.values {
            addPlugin(erasedPlugin, id: id, to: workspace)
        }
    }

    public func unregisterPlugin<Plugin: WorkspacePlugin>(_: Plugin.Type) {
        let id = ObjectIdentifier(Plugin.self)
        plugins[id] = nil

        for workspace in workspaces.values {
            removePlugin(id: id, from: workspace)
        }
    }

    public func fetchFilespaceIfExisted(fileURL: URL) -> Filespace? {
        for workspace in workspaces.values {
            if let filespace = workspace.filespaces[fileURL] {
                return filespace
            }
        }
        return nil
    }

    @WorkspaceActor
    public func fetchOrCreateWorkspace(workspaceURL: URL) async throws -> Workspace {
        guard workspaceURL != URL(fileURLWithPath: "/") else {
            throw Error.invalidWorkspaceURL(workspaceURL)
        }

        if let existed = workspaces[workspaceURL] {
            return existed
        }

        let new = createNewWorkspace(workspaceURL: workspaceURL)
        workspaces[workspaceURL] = new
        return new
    }

    @WorkspaceActor
    public func fetchOrCreateWorkspaceAndFilespace(fileURL: URL) async throws
        -> (workspace: Workspace, filespace: Filespace)
    {
        // If we can get the workspace URL directly.
        if let currentWorkspaceURL = await XcodeInspector.shared.safe.realtimeActiveWorkspaceURL {
            if let existed = workspaces[currentWorkspaceURL] {
                // Reuse the existed workspace.
                let filespace = existed.createFilespaceIfNeeded(fileURL: fileURL)
                return (existed, filespace)
            }

            let new = createNewWorkspace(workspaceURL: currentWorkspaceURL)
            workspaces[currentWorkspaceURL] = new
            let filespace = new.createFilespaceIfNeeded(fileURL: fileURL)
            return (new, filespace)
        }

        // If not, we try to reuse a filespace if found.
        //
        // Sometimes, we can't get the project root path from Xcode window, for example, when the
        // quick open window in displayed.
        for workspace in workspaces.values {
            if let filespace = workspace.filespaces[fileURL] {
                return (workspace, filespace)
            }
        }

        // If we can't find the workspace URL, we will try to guess it.
        // Most of the time we won't enter this branch, just incase.

        if let workspaceURL = WorkspaceXcodeWindowInspector.extractProjectURL(
            workspaceURL: nil,
            documentURL: fileURL
        ) {
            let workspace = {
                if let existed = workspaces[workspaceURL] {
                    return existed
                }
                // Reuse existed workspace if possible
                for (_, workspace) in workspaces {
                    if fileURL.path.hasPrefix(workspace.projectRootURL.path) {
                        return workspace
                    }
                }
                return createNewWorkspace(workspaceURL: workspaceURL)
            }()

            let filespace = workspace.createFilespaceIfNeeded(fileURL: fileURL)
            workspaces[workspaceURL] = workspace
            workspace.refreshUpdateTime()
            return (workspace, filespace)
        }
        
        throw Workspace.CantFindWorkspaceError()
    }

    @WorkspaceActor
    public func removeWorkspace(url: URL) {
        workspaces[url] = nil
    }
}

extension WorkspacePool {
    func addPlugin(
        _ plugin: (Workspace) -> WorkspacePlugin,
        id: ObjectIdentifier,
        to workspace: Workspace
    ) {
        if workspace.plugins[id] != nil { return }
        workspace.plugins[id] = plugin(workspace)
    }

    func removePlugin(id: ObjectIdentifier, from workspace: Workspace) {
        workspace.plugins[id] = nil
    }

    func createNewWorkspace(workspaceURL: URL) -> Workspace {
        let new = Workspace(workspaceURL: workspaceURL)
        for (id, plugin) in plugins {
            addPlugin(plugin, id: id, to: new)
        }
        return new
    }
}

