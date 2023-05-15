import Foundation
import Terminal

public struct GitHubCopilotInstallationManager {
    private static var isInstalling = false

    public init() {}

    public enum InstallationStatus {
        case notInstalled
        case installed
    }

    public func checkInstallation() -> InstallationStatus {
        guard let urls = try? GitHubCopilotBaseService.createFoldersIfNeeded()
        else { return .notInstalled }
        let executableFolderURL = urls.executableURL
        let binaryURL = executableFolderURL.appendingPathComponent("copilot")

        if !FileManager.default.fileExists(atPath: binaryURL.path) {
            return .notInstalled
        }

        return .installed
    }

    public enum InstallationStep {
        case downloading
        case uninstalling
        case decompressing
        case done
    }

    public enum Error: Swift.Error, LocalizedError {
        case isInstalling
        case failedToFindLanguageServer

        public var errorDescription: String? {
            switch self {
            case .isInstalling:
                return "Language server is installing."
            case .failedToFindLanguageServer:
                return "Failed to find language server. Please open an issue on GitHub."
            }
        }
    }

    public func installLatestVersion() -> AsyncThrowingStream<InstallationStep, Swift.Error> {
        AsyncThrowingStream<InstallationStep, Swift.Error> { continuation in
            Task {
                guard !GitHubCopilotInstallationManager.isInstalling else {
                    continuation.finish(throwing: Error.isInstalling)
                    return
                }
                GitHubCopilotInstallationManager.isInstalling = true
                defer { GitHubCopilotInstallationManager.isInstalling = false }
                do {
                    continuation.yield(.downloading)
                    let urls = try GitHubCopilotBaseService.createFoldersIfNeeded()
                    let executable = Bundle.main.bundleURL.appendingPathComponent("Contents/Applications/CopilotForXcodeExtensionService.app/Contents/Resources/copilot")
                    guard FileManager.default.fileExists(atPath: executable.path) else {
                        throw Error.failedToFindLanguageServer
                    }
                    
                    let targetURL = urls.executableURL.appendingPathComponent("copilot")

                    try FileManager.default.copyItem(
                        at: executable,
                        to: targetURL
                    )

                    // update permission 755
                    try FileManager.default.setAttributes(
                        [.posixPermissions: 0o755],
                        ofItemAtPath: targetURL.path
                    )

                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func uninstall() async throws {
        guard let urls = try? GitHubCopilotBaseService.createFoldersIfNeeded()
        else { return }
        let executableFolderURL = urls.executableURL
        let binaryURL = executableFolderURL.appendingPathComponent("copilot")
        if FileManager.default.fileExists(atPath: binaryURL.path) {
            try FileManager.default.removeItem(at: binaryURL)
        }
    }
}
