import Foundation
import Terminal

public struct GitHubCopilotInstallationManager {
    private static var isInstalling = false

    static var downloadURL: URL {
        let commitHash = "1358e8e45ecedc53daf971924a0541ddf6224faf"
        let link = "https://github.com/github/copilot.vim/archive/\(commitHash).zip"
        return URL(string: link)!
    }

    static let latestSupportedVersion = "1.8.4"

    public init() {}

    public enum InstallationStatus {
        case notInstalled
        case installed(String)
        case outdated(current: String, latest: String)
        case unsupported(current: String, latest: String)
    }

    public func checkInstallation() -> InstallationStatus {
        guard let urls = try? GitHubCopilotBaseService.createFoldersIfNeeded()
        else { return .notInstalled }
        let executableFolderURL = urls.executableURL
        let binaryURL = executableFolderURL.appendingPathComponent("copilot")
        let versionFileURL = executableFolderURL.appendingPathComponent("version")

        if !FileManager.default.fileExists(atPath: binaryURL.path) {
            return .notInstalled
        }

        if FileManager.default.fileExists(atPath: versionFileURL.path),
           let versionData = try? Data(contentsOf: versionFileURL),
           let version = String(data: versionData, encoding: .utf8)
        {
            switch version.compare(Self.latestSupportedVersion) {
            case .orderedAscending:
                return .outdated(current: version, latest: Self.latestSupportedVersion)
            case .orderedSame:
                return .installed(version)
            case .orderedDescending:
                return .unsupported(current: version, latest: Self.latestSupportedVersion)
            }
        }

        return .outdated(current: "Unknown", latest: Self.latestSupportedVersion)
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
        case failedToInstallLanguageServer

        public var errorDescription: String? {
            switch self {
            case .isInstalling:
                return "Language server is installing."
            case .failedToFindLanguageServer:
                return "Failed to find language server. Please open an issue on GitHub."
            case .failedToInstallLanguageServer:
                return "Failed to install language server. Please open an issue on GitHub."
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

                    // download
                    let (fileURL, _) = try await URLSession.shared.download(from: Self.downloadURL)
                    let targetURL = urls.executableURL.appendingPathComponent("archive")
                        .appendingPathExtension("zip")
                    try FileManager.default.copyItem(at: fileURL, to: targetURL)
                    defer { try? FileManager.default.removeItem(at: targetURL) }

                    // uninstall
                    continuation.yield(.uninstalling)
                    try await uninstall()

                    // decompress
                    continuation.yield(.decompressing)
                    let terminal = Terminal()

                    _ = try await terminal.runCommand(
                        "/usr/bin/unzip",
                        arguments: [targetURL.path],
                        currentDirectoryPath: urls.executableURL.path,
                        environment: [:]
                    )

                    let contentURLs = try FileManager.default.contentsOfDirectory(
                        at: urls.executableURL,
                        includingPropertiesForKeys: nil,
                        options: []
                    )
                    
                    defer {
                        for url in contentURLs {
                            try? FileManager.default.removeItem(at: url)
                        }
                    }

                    guard let gitFolderURL = contentURLs
                        .first(where: { $0.lastPathComponent.hasPrefix("copilot.vim") })
                    else {
                        continuation.finish(throwing: Error.failedToInstallLanguageServer)
                        return
                    }

                    let lspURL = gitFolderURL.appendingPathComponent("copilot")
                    let installationURL = urls.executableURL.appendingPathComponent("copilot")
                    try FileManager.default.copyItem(at: lspURL, to: installationURL)

                    // update permission 755
                    try FileManager.default.setAttributes(
                        [.posixPermissions: 0o755],
                        ofItemAtPath: installationURL.path
                    )

                    // create version file
                    let data = Self.latestSupportedVersion.data(using: .utf8)
                    FileManager.default.createFile(
                        atPath: urls.executableURL.appendingPathComponent("version").path,
                        contents: data
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
        let versionFileURL = executableFolderURL.appendingPathComponent("version")
        if FileManager.default.fileExists(atPath: binaryURL.path) {
            try FileManager.default.removeItem(at: binaryURL)
        }
        if FileManager.default.fileExists(atPath: versionFileURL.path) {
            try FileManager.default.removeItem(at: versionFileURL)
        }
    }
}

