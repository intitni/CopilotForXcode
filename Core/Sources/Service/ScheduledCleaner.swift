import ActiveApplicationMonitor
import AppKit
import AXExtension
import Foundation

public final class ScheduledCleaner {
    public init() {
        // occasionally cleanup workspaces.
        Task { @ServiceActor in
            while !Task.isCancelled {
                try await Task.sleep(nanoseconds: 2 * 60 * 60 * 1_000_000_000)
                let availableTabs = findAvailableOpenedTabs()
                for (url, workspace) in workspaces {
                    if workspace.isExpired {
                        workspaces[url] = nil
                    } else {
                        // cleanup chats for unused files
                        let filespaces = workspace.filespaces
                        for (url, _) in filespaces {
                            if workspace.isFilespaceExpired(
                                fileURL: url,
                                availableTabs: availableTabs
                            ) {
                                WidgetDataSource.shared.cleanup(for: url)
                            }
                        }
                        // cleanup workspace
                        workspace.cleanUp(availableTabs: availableTabs)
                    }
                }
            }
        }
    }

    func findAvailableOpenedTabs() -> Set<String> {
        guard let xcode = ActiveApplicationMonitor.latestXcode else { return [] }
        let app = AXUIElementCreateApplication(xcode.processIdentifier)
        let windows = app.windows.filter { $0.identifier == "Xcode.WorkspaceWindow" }
        guard !windows.isEmpty else { return [] }
        var allTabs = Set<String>()
        for window in windows {
            guard let editArea = window.firstChild(where: { $0.description == "editor area" })
            else { continue }
            let tabBars = editArea.children { $0.description == "tab bar" }
            for tabBar in tabBars {
                let tabs = tabBar.children { $0.roleDescription == "tab" }
                for tab in tabs {
                    allTabs.insert(tab.title)
                }
            }
        }
        return allTabs
    }
}

