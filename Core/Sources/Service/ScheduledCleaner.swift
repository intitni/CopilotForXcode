import Foundation

public final class ScheduledCleaner {
    public init() {
        // occasionally cleanup workspaces.
        Task { @ServiceActor in
            while !Task.isCancelled {
                try await Task.sleep(nanoseconds: 8 * 60 * 60 * 1_000_000_000)
                for (url, workspace) in workspaces {
                    if workspace.isExpired {
                        workspaces[url] = nil
                    } else {
                        // cleanup chats for unused files
                        let filespaces = workspace.filespaces
                        for (url, filespace) in filespaces {
                            if filespace.isExpired {
                                WidgetDataSource.shared.chats[url] = nil
                                WidgetDataSource.shared.chatProviders[url] = nil
                            }
                        }
                        // cleanup workspace
                        workspace.cleanUp()
                    }
                }
            }
        }
    }
}
