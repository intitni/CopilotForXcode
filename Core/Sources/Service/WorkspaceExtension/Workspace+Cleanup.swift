import Foundation
import SuggestionProvider
import Workspace
import WorkspaceSuggestionService

extension Workspace {
    @WorkspaceActor
    func cleanUp(availableTabs: Set<String>) {
        for (fileURL, _) in filespaces {
            if isFilespaceExpired(fileURL: fileURL, availableTabs: availableTabs) {
                openedFileRecoverableStorage.closeFile(fileURL: fileURL)
                closeFilespace(fileURL: fileURL)
            }
        }
    }

    func isFilespaceExpired(fileURL: URL, availableTabs: Set<String>) -> Bool {
        let filename = fileURL.lastPathComponent
        if availableTabs.contains(filename) { return false }
        guard let filespace = filespaces[fileURL] else { return true }
        return filespace.isExpired
    }

    func cancelInFlightRealtimeSuggestionRequests() async {
        guard let suggestionService else { return }
        await suggestionService.cancelRequest(workspaceInfo: .init(
            workspaceURL: workspaceURL,
            projectURL: projectRootURL
        ))
    }
}

