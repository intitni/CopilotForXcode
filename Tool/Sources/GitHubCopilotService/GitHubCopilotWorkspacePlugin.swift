import Foundation
import Logger
import Workspace

public final class GitHubCopilotWorkspacePlugin: WorkspacePlugin {
    private var _gitHubCopilotService: GitHubCopilotService?
    @GitHubCopilotSuggestionActor
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
        if let _gitHubCopilotService {
            Task { await _gitHubCopilotService.terminate() }
        }
    }

    @GitHubCopilotSuggestionActor
    func createGitHubCopilotService() throws -> GitHubCopilotService {
        let newService = try GitHubCopilotService(projectRootURL: projectRootURL)
        _gitHubCopilotService = newService
        newService.localProcessServer?.terminationHandler = { [weak self] in
            Logger.gitHubCopilot.error("GitHub Copilot language server terminated")
            self?.terminate()
        }
        Task {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            finishLaunchingService()
        }
        return newService
    }

    @GitHubCopilotSuggestionActor
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

