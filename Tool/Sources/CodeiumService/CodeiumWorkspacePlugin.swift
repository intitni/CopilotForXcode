import Foundation
import Logger
import Workspace

public final class CodeiumWorkspacePlugin: WorkspacePlugin {
    var _codeiumService: CodeiumService?
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
        if let codeiumService {
            codeiumService.terminate()
        }
    }

    func createCodeiumService() throws -> CodeiumService {
        let newService = try CodeiumService(
            projectRootURL: projectRootURL,
            onServiceLaunched: {
                [weak self] in
                self?.finishLaunchingService()
            }
        )
        _codeiumService = newService
        return newService
    }

    func finishLaunchingService() {
        guard let workspace, let _codeiumService else { return }
        Task {
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

