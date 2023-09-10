import Environment
import Foundation

@globalActor public enum WorkspaceActor {
    public actor TheActor {}
    public static let shared = TheActor()
}

public class WorkspacePool {
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
    public func fetchOrCreateWorkspaceAndFilespace(fileURL: URL) async throws
        -> (workspace: Workspace, filespace: Filespace)
    {
        let ignoreFileExtensions = ["mlmodel"]
        if ignoreFileExtensions.contains(fileURL.pathExtension) {
            throw Workspace.UnsupportedFileError(extensionName: fileURL.pathExtension)
        }

        // If we know which project is opened.
        if let currentWorkspaceURL = try await Environment.fetchCurrentWorkspaceURLFromXcode() {
            if let existed = workspaces[currentWorkspaceURL] {
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

        // If we can't find an existed one, we will try to guess it.
        // Most of the time we won't enter this branch, just incase.

        let workspaceURL = try await Environment.guessProjectRootURLForFile(fileURL)

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

