import ActiveApplicationMonitor
import AppKit
import AXExtension
import Foundation
import Logger
import XcodeInspector

public final class ScheduledCleaner {
    public init() {
        // occasionally cleanup workspaces.
        Task { @ServiceActor in
            while !Task.isCancelled {
                try await Task.sleep(nanoseconds: 10 * 60 * 1_000_000_000)
                cleanUp()
            }
        }

        // cleanup when Xcode becomes inactive
        Task { @ServiceActor in
            for await app in ActiveApplicationMonitor.createStream() {
                try Task.checkCancellation()
                if let app, !app.isXcode {
                    cleanUp()
                }
            }
        }
    }

    @ServiceActor
    func cleanUp() {
        let workspaceInfos = XcodeInspector.shared.xcodes.reduce(
            into: [
                XcodeAppInstanceInspector.WorkspaceIdentifier:
                    XcodeAppInstanceInspector.WorkspaceInfo
            ]()
        ) { result, xcode in
            let infos = xcode.realtimeWorkspaces
            for (id, info) in infos {
                if let existed = result[id] {
                    result[id] = existed.combined(with: info)
                } else {
                    result[id] = info
                }
            }
        }
        for (url, workspace) in workspaces {
            if workspace.isExpired, workspaceInfos[.url(url)] == nil {
                Logger.service.info("Remove idle workspace")
                for url in workspace.filespaces.keys {
                    WidgetDataSource.shared.cleanup(for: url)
                }
                workspace.cleanUp(availableTabs: [])
                workspaces[url] = nil
            } else {
                let tabs = (workspaceInfos[.url(url)]?.tabs ?? [])
                    .union(workspaceInfos[.unknown]?.tabs ?? [])
                // cleanup chats for unused files
                let filespaces = workspace.filespaces
                for (url, _) in filespaces {
                    if workspace.isFilespaceExpired(
                        fileURL: url,
                        availableTabs: tabs
                    ) {
                        Logger.service.info("Remove idle filespace")
                        WidgetDataSource.shared.cleanup(for: url)
                    }
                }
                // cleanup workspace
                workspace.cleanUp(availableTabs: tabs)
            }
        }
    }
    
    @ServiceActor
    public func closeAllChildProcesses() async {
        for (_, workspace) in workspaces {
            await workspace.terminateSuggestionService()
        }
    }
}

