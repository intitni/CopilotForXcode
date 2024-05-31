import Foundation
import Logger
import Workspace
import Toast
import Dependencies

public final class GitHubCopilotWorkspacePlugin: WorkspacePlugin {
    enum Error: Swift.Error, LocalizedError {
        case gitHubCopilotLanguageServerMustBeUpdated
        var errorDescription: String? {
            switch self {
            case .gitHubCopilotLanguageServerMustBeUpdated:
                return "GitHub Copilot language server must be updated. Update will start immediately. \nIf it fails, please go to Host app > Service > GitHub Copilot and check if there is an update available."
            }
        }
    }
    
    @Dependency(\.toast) var toast

    let installationManager = GitHubCopilotInstallationManager()
    private var _gitHubCopilotService: GitHubCopilotService?
    @GitHubCopilotSuggestionActor
    var gitHubCopilotService: GitHubCopilotService? {
        if let service = _gitHubCopilotService { return service }
        do {
            return try createGitHubCopilotService()
        } catch let error as Error {
            toast(error.localizedDescription, .warning)
            Task {
                await updateLanguageServerIfPossible()
            }
            return nil
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
        if case .outdated(_, _, true) = installationManager.checkInstallation() {
            throw Error.gitHubCopilotLanguageServerMustBeUpdated
        }
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
    
    @GitHubCopilotSuggestionActor
    func updateLanguageServerIfPossible() async {
        guard !GitHubCopilotInstallationManager.isInstalling else { return }
        let events = installationManager.installLatestVersion()
        do {
            for try await event in events {
                switch event {
                case .downloading:
                    toast("Updating GitHub Copilot language server", .info)
                case .uninstalling:
                    break
                case .decompressing:
                    break
                case .done:
                    toast("Finished updating GitHub Copilot language server", .info)
                }
            }
        } catch GitHubCopilotInstallationManager.Error.isInstalling {
            return
        } catch {
            toast(error.localizedDescription, .error)
        }
    }

    func terminate() {
        _gitHubCopilotService = nil
    }
}

