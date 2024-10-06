import Foundation
import Terminal

public struct CodeiumInstallationManager {
    private static var isInstalling = false
    static let latestSupportedVersion = "1.20.9"
    static let minimumSupportedVersion = "1.20.0"

    public init() {}

    enum CodeiumInstallationError: Error, LocalizedError {
        case badURL(String)
        case invalidResponse
        case invalidData

        var errorDescription: String? {
            switch self {
            case .badURL: return "URL is invalid"
            case .invalidResponse: return "Invalid response"
            case .invalidData: return "Invalid data"
            }
        }
    }

    public func getLatestSupportedVersion() -> String {
        if isEnterprise {
            return UserDefaults.shared.value(for: \.codeiumEnterpriseVersion)
        }

        return Self.latestSupportedVersion
    }

    func getEnterprisePortalVersion() async throws -> String {
        let enterprisePortalUrl = UserDefaults.shared.value(for: \.codeiumPortalUrl)
        let enterprisePortalVersionUrl = "\(enterprisePortalUrl)/api/version"

        guard let url = URL(string: enterprisePortalVersionUrl)
        else { throw CodeiumInstallationError.badURL(enterprisePortalVersionUrl) }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw CodeiumInstallationError.invalidResponse
        }

        if let version = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        {
            UserDefaults.shared.set(version, for: \.codeiumEnterpriseVersion)
            return version
        } else {
            return UserDefaults.shared.value(for: \.codeiumEnterpriseVersion)
        }
    }

    var isEnterprise: Bool {
        return UserDefaults.shared.value(for: \.codeiumEnterpriseMode)
            && !UserDefaults.shared.value(for: \.codeiumPortalUrl).isEmpty
    }

    public enum InstallationStatus {
        case notInstalled
        case installed(String)
        case outdated(current: String, latest: String, mandatory: Bool)
        case unsupported(current: String, latest: String)
    }

    public func checkInstallation() async -> InstallationStatus {
        guard let urls = try? CodeiumService.createFoldersIfNeeded()
        else { return .notInstalled }
        let executableFolderURL = urls.executableURL
        let binaryURL = executableFolderURL.appendingPathComponent("language_server")
        let versionFileURL = executableFolderURL.appendingPathComponent("version")

        if !FileManager.default.fileExists(atPath: binaryURL.path) {
            return .notInstalled
        }

        let targetVersion = await {
            if !isEnterprise { return Self.latestSupportedVersion }
            return (try? await getEnterprisePortalVersion())
                ?? UserDefaults.shared.value(for: \.codeiumEnterpriseVersion)
        }()

        if FileManager.default.fileExists(atPath: versionFileURL.path),
           let versionData = try? Data(contentsOf: versionFileURL),
           let version = String(data: versionData, encoding: .utf8)
        {
            switch version.compare(targetVersion, options: .numeric) {
            case .orderedAscending:
                switch version.compare(Self.minimumSupportedVersion) {
                case .orderedAscending:
                    return .outdated(current: version, latest: Self.latestSupportedVersion, mandatory: true)
                case .orderedSame:
                    return .outdated(current: version, latest: Self.latestSupportedVersion, mandatory: false)
                case .orderedDescending:
                    return .outdated(current: version, latest: Self.latestSupportedVersion, mandatory: false)
                }
            case .orderedSame:
                return .installed(version)
            case .orderedDescending:
                return .unsupported(current: version, latest: targetVersion)
            }
        }
        return .outdated(current: "Unknown", latest: Self.latestSupportedVersion, mandatory: false)
    }

    public enum InstallationStep {
        case downloading
        case uninstalling
        case decompressing
        case done
    }

    public func installLatestVersion() -> AsyncThrowingStream<InstallationStep, Error> {
        AsyncThrowingStream<InstallationStep, Error> { continuation in
            Task {
                guard !CodeiumInstallationManager.isInstalling else {
                    continuation.finish(throwing: CodeiumError.languageServiceIsInstalling)
                    return
                }
                CodeiumInstallationManager.isInstalling = true
                defer { CodeiumInstallationManager.isInstalling = false }
                do {
                    continuation.yield(.downloading)
                    let urls = try CodeiumService.createFoldersIfNeeded()
                    let urlString: String
                    let version: String
                    if !isEnterprise {
                        version = CodeiumInstallationManager.latestSupportedVersion
                        urlString =
                            "https://github.com/Exafunction/codeium/releases/download/language-server-v\(Self.latestSupportedVersion)/language_server_macos_\(isAppleSilicon() ? "arm" : "x64").gz"
                    } else {
                        version = try await getEnterprisePortalVersion()
                        let enterprisePortalUrl = UserDefaults.shared.value(for: \.codeiumPortalUrl)
                        urlString =
                            "\(enterprisePortalUrl)/language-server-v\(version)/language_server_macos_\(isAppleSilicon() ? "arm" : "x64").gz"
                    }

                    guard let url = URL(string: urlString) else {
                        continuation.finish(throwing: CodeiumInstallationError.badURL(urlString))
                        return
                    }

                    // download
                    let (fileURL, _) = try await URLSession.shared.download(from: url)
                    let targetURL = urls.executableURL.appendingPathComponent("language_server")
                        .appendingPathExtension("gz")
                    try FileManager.default.copyItem(at: fileURL, to: targetURL)
                    defer { try? FileManager.default.removeItem(at: targetURL) }

                    // uninstall
                    continuation.yield(.uninstalling)
                    try await uninstall()

                    // extract file
                    continuation.yield(.decompressing)
                    let terminal = Terminal()
                    _ = try await terminal.runCommand(
                        "/usr/bin/gunzip",
                        arguments: [targetURL.path],
                        environment: [:]
                    )

                    // update permission 755
                    try FileManager.default.setAttributes(
                        [.posixPermissions: 0o755],
                        ofItemAtPath: targetURL.deletingPathExtension().path
                    )
                    var data: Data?

                    // create version file
                    data = version.data(using: .utf8)

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
        guard let urls = try? CodeiumService.createFoldersIfNeeded()
        else { return }
        let executableFolderURL = urls.executableURL
        let binaryURL = executableFolderURL.appendingPathComponent("language_server")
        let versionFileURL = executableFolderURL.appendingPathComponent("version")
        if FileManager.default.fileExists(atPath: binaryURL.path) {
            try FileManager.default.removeItem(at: binaryURL)
        }
        if FileManager.default.fileExists(atPath: versionFileURL.path) {
            try FileManager.default.removeItem(at: versionFileURL)
        }
    }
}

func isAppleSilicon() -> Bool {
    var result = false
    #if arch(arm64)
    result = true
    #endif
    return result
}

