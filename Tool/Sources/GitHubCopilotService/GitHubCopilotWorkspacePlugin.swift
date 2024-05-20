import Foundation
import Logger
import Workspace

public final class GitHubCopilotWorkspacePlugin: WorkspacePlugin {
    var _gitHubCopilotService: GitHubCopilotService?
    var gitHubCopilotService: GitHubCopilotService? {
        if let service = _gitHubCopilotService { return service }
        do {
            return try createGitHubCopilotService()
        } catch {
            Logger.gitHubCopilot.error("Failed to create GitHub Copilot service: \(error)")
            return nil
        }
    }

    deinit {
        if let gitHubCopilotService {
            Task { await gitHubCopilotService.terminate() }
        }
    }

    func createGitHubCopilotService() throws -> GitHubCopilotService {
        let newService = try GitHubCopilotService(projectRootURL: projectRootURL)
        _gitHubCopilotService = newService
        Task {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            finishLaunchingService()
        }
        return newService
    }

    func finishLaunchingService() {
        guard let workspace, let _gitHubCopilotService else { return }
        Task {
            for (_, filespace) in workspace.filespaces {
                let documentURL = filespace.fileURL
                guard let content = try? String(contentsOf: documentURL) else { continue }
                try? await _gitHubCopilotService.notifyOpenTextDocument(
                    fileURL: documentURL,
                    content: content
                )
            }
        }
    }

    func terminate() {
        _gitHubCopilotService = nil
    }
}

