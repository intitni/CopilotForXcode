import Foundation
import LanguageServerProtocol

extension FileManager {
    func fileIsDirectory(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileExists(atPath: path, isDirectory: &isDirectory)
        return isDirectory.boolValue && exists
    }
}

@discardableResult
func runAppleScript(_ appleScript: String) async throws -> String {
    let task = Process()
    task.launchPath = "/usr/bin/osascript"
    task.arguments = ["-e", appleScript]
    let outpipe = Pipe()
    task.standardOutput = outpipe

    return try await withUnsafeThrowingContinuation { continuation in
        do {
            task.terminationHandler = { _ in
                do {
                    if let data = try outpipe.fileHandleForReading.readToEnd(),
                       let content = String(data: data, encoding: .utf8)
                    {
                        continuation.resume(returning: content)
                        return
                    }
                    continuation.resume(returning: "")
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            try task.run()
        } catch {
            continuation.resume(throwing: error)
        }
    }
}

extension XPCService {
    @ServiceActor
    func fetchOrCreateWorkspaceIfNeeded(fileURL: URL) async throws -> Workspace {
        let projectURL = try await Environment.fetchCurrentProjectRootURL(fileURL)
        let workspaceURL = projectURL ?? fileURL
        let workspace = workspaces[workspaceURL] ?? Workspace(projectRootURL: workspaceURL)
        workspaces[workspaceURL] = workspace
        return workspace
    }
}

extension NSError {
    static func from(_ error: Error) -> NSError {
        if let error = error as? ServerError {
            var message = "Unknown"
            switch error {
            case let .handlerUnavailable(handler):
                message = "Handler unavailable: \(handler)."
            case let .unhandledMethod(method):
                message = "Methond unhandled: \(method)."
            case let .notificationDispatchFailed(error):
                message = "Notification dispatch failed: \(error.localizedDescription)."
            case let .requestDispatchFailed(error):
                message = "Request dispatch failed: \(error.localizedDescription)."
            case let .clientDataUnavailable(error):
                message = "Client data unavalable: \(error.localizedDescription)."
            case .serverUnavailable:
                message = "Server unavailable, please make sure you have installed Node."
            case .missingExpectedParameter:
                message = "Missing expected parameter."
            case .missingExpectedResult:
                message = "Missing expected result."
            case let .unableToDecodeRequest(error):
                message = "Unable to decode request: \(error.localizedDescription)."
            case let .unableToSendRequest(error):
                message = "Unable to send request: \(error.localizedDescription)."
            case let .unableToSendNotification(error):
                message = "Unable to send notification: \(error.localizedDescription)."
            case let .serverError(code, m, _):
                message = "Server error: (\(code)) \(m)."
            case let .invalidRequest(error):
                message = "Invalid request: \(error?.localizedDescription ?? "Unknown")."
            case .timeout:
                message = "Timeout."
            }
            return NSError(domain: "com.intii.CopilotForXcode", code: -1, userInfo: [
                NSLocalizedDescriptionKey: message,
            ])
        }
        if let error = error as? CancellationError {
            return NSError(domain: "com.intii.CopilotForXcode", code: -100, userInfo: [
                NSLocalizedDescriptionKey: error.localizedDescription,
            ])
        }
        return NSError(domain: "com.intii.CopilotForXcode", code: -1, userInfo: [
            NSLocalizedDescriptionKey: error.localizedDescription,
        ])
    }
}
