import Dependencies
import Foundation
import Terminal
import Preferences

public struct CheckIfGitIgnoredDependencyKey: DependencyKey {
    public static var liveValue: GitIgnoredChecker = DefaultGitIgnoredChecker()
}

public extension DependencyValues {
    var gitIgnoredChecker: GitIgnoredChecker {
        get { self[CheckIfGitIgnoredDependencyKey.self] }
        set { self[CheckIfGitIgnoredDependencyKey.self] = newValue }
    }
}

public protocol GitIgnoredChecker {
    func checkIfGitIgnored(fileURL: URL) async -> Bool
}

extension GitIgnoredChecker {
    func checkIfGitIgnored(filePath: String) async -> Bool {
        await checkIfGitIgnored(fileURL: URL(fileURLWithPath: filePath))
    }
}

struct DefaultGitIgnoredChecker: GitIgnoredChecker {
    func checkIfGitIgnored(fileURL: URL) async -> Bool {
        if UserDefaults.shared.value(for: \.disableGitIgnoreCheck) { return false }
        let terminal = Terminal()
        guard let gitFolderURL = gitFolderURL(forFileURL: fileURL) else {
            return false
        }
        do {
            _ = try await terminal.runCommand(
                "/bin/bash",
                arguments: ["-c", "check-ignore \"filePath\""],
                currentDirectoryPath: gitFolderURL.path,
                environment: [:]
            )
            return true
        } catch {
            return false
        }
    }
}

func gitFolderURL(forFileURL fileURL: URL) -> URL? {
    var currentURL = fileURL
    let fileManager = FileManager.default
    while currentURL.path != "/" {
        let gitFolderURL = currentURL.appendingPathComponent(".git")
        if fileManager.fileExists(atPath: gitFolderURL.path) {
            return gitFolderURL
        }
        currentURL = currentURL.deletingLastPathComponent()
    }
    return nil
}

