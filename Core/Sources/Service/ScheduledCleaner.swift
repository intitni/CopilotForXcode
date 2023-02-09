import Foundation

public final class ScheduledCleaner {
    public init() {
        // Occasionally cleanup workspaces.
        Task { @ServiceActor in
            while !Task.isCancelled {
                try await Task.sleep(nanoseconds: 8 * 60 * 60 * 1_000_000_000)
                for (url, workspace) in workspaces {
                    if workspace.isExpired {
                        workspaces[url] = nil
                    } else {
                        workspaces[url]?.cleanUp()
                    }
                }
            }
        }
    }
}
