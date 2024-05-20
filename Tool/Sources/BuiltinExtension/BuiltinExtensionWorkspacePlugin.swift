import Foundation
import Workspace

public final class BuiltinExtensionWorkspacePlugin: WorkspacePlugin {
    let extensionManager: BuiltinExtensionManager

    public init(workspace: Workspace, extensionManager: BuiltinExtensionManager = .shared) {
        self.extensionManager = extensionManager
        super.init(workspace: workspace)
    }

    override public func didOpenFilespace(_ filespace: Filespace) {
        notifyOpenFile(filespace: filespace)
    }

    override public func didSaveFilespace(_ filespace: Filespace) {
        notifySaveFile(filespace: filespace)
    }

    override public func didUpdateFilespace(_ filespace: Filespace, content: String) {
        notifyUpdateFile(filespace: filespace, content: content)
    }

    override public func didCloseFilespace(_ fileURL: URL) {
        Task {
            for ext in extensionManager.extensions {
                ext.workspace(
                    .init(workspaceURL: workspaceURL, projectURL: projectRootURL),
                    didCloseDocumentAt: fileURL
                )
            }
        }
    }

    public func notifyOpenFile(filespace: Filespace) {
        Task {
            guard filespace.isTextReadable else { return }
            guard !(await filespace.isGitIgnored) else { return }
            for ext in extensionManager.extensions {
                ext.workspace(
                    .init(workspaceURL: workspaceURL, projectURL: projectRootURL),
                    didOpenDocumentAt: filespace.fileURL
                )
            }
        }
    }

    public func notifyUpdateFile(filespace: Filespace, content: String) {
        Task {
            guard filespace.isTextReadable else { return }
            guard !(await filespace.isGitIgnored) else { return }
            for ext in extensionManager.extensions {
                ext.workspace(
                    .init(workspaceURL: workspaceURL, projectURL: projectRootURL),
                    didUpdateDocumentAt: filespace.fileURL, 
                    content: content
                )
            }
        }
    }

    public func notifySaveFile(filespace: Filespace) {
        Task {
            guard filespace.isTextReadable else { return }
            guard !(await filespace.isGitIgnored) else { return }
            for ext in extensionManager.extensions {
                ext.workspace(
                    .init(workspaceURL: workspaceURL, projectURL: projectRootURL),
                    didSaveDocumentAt: filespace.fileURL
                )
            }
        }
    }
}

