import Foundation
import Logger
import Workspace

public final class CodeiumWorkspacePlugin: WorkspacePlugin {
    private var _codeiumService: CodeiumService?
    @CodeiumActor
    var codeiumService: CodeiumService? {
        if let service = _codeiumService { return service }
        do {
            return try createCodeiumService()
        } catch {
            Logger.codeium.error("Failed to create Codeium service: \(error)")
            return nil
        }
    }

    deinit {
        if let _codeiumService {
            _codeiumService.terminate()
        }
    }

    @CodeiumActor
    func createCodeiumService() throws -> CodeiumService {
        let newService = try CodeiumService(
            projectRootURL: projectRootURL,
            onServiceLaunched: {

            },
            onServiceTerminated: {
                // start handled in the service.
            }
        )
        _codeiumService = newService
        return newService
    }

    @CodeiumActor
    func finishLaunchingService() {
        guard let workspace, let _codeiumService else { return }
        Task {
            try? await _codeiumService.notifyOpenWorkspace(workspaceURL: workspaceURL)
            
            for (_, filespace) in workspace.filespaces {
                let documentURL = filespace.fileURL
                guard let content = try? String(contentsOf: documentURL) else { continue }
                try? await _codeiumService.notifyOpenTextDocument(
                    fileURL: documentURL,
                    content: content
                )
            }
        }
    }

    func terminate() {
        _codeiumService = nil
    }
}

