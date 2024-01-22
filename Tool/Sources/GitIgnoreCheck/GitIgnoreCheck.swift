import Dependencies
import Foundation
import Terminal
import Preferences

public struct CheckIfGitIgnoredDependencyKey: DependencyKey {
    public static var liveValue: GitIgnoredChecker = DefaultGitIgnoredChecker()
    public static var testValue: GitIgnoredChecker = DefaultGitIgnoredChecker(isTest: true)
}

public extension DependencyValues {
    var gitIgnoredChecker: GitIgnoredChecker {
        get { self[CheckIfGitIgnoredDependencyKey.self] }
        set { self[CheckIfGitIgnoredDependencyKey.self] = newValue }
    }
}

public protocol GitIgnoredChecker {
    func checkIfGitIgnored(fileURL: URL) async -> Bool
    func checkIfGitIgnored(fileURLs: [URL]) async -> [URL]
}

public extension GitIgnoredChecker {
    func checkIfGitIgnored(filePath: String) async -> Bool {
        await checkIfGitIgnored(fileURL: URL(fileURLWithPath: filePath))
    }
    
    func checkIfGitIgnored(filePaths: [String]) async -> [String] {
        await checkIfGitIgnored(fileURLs: filePaths.map { URL(fileURLWithPath: $0) })
            .map(\.path)
    }
}

public struct DefaultGitIgnoredChecker: GitIgnoredChecker {
    var isTest = false
    
    var noCheck: Bool {
        if isTest { return true }
        return UserDefaults.shared.value(for: \.disableGitIgnoreCheck)
    }
    
    public init() {}
    
    init(isTest: Bool) {
        self.isTest = isTest
    }
    
    public func checkIfGitIgnored(fileURL: URL) async -> Bool {
        if noCheck { return false }
        let terminal = Terminal()
        guard let gitFolderURL = gitFolderURL(forFileURL: fileURL) else {
            return false
        }
        do {
            let result = try await terminal.runCommand(
                "/bin/bash",
                arguments: ["-c", "git check-ignore \"\(fileURL.path)\""],
                currentDirectoryURL: gitFolderURL,
                environment: [:]
            )
            if result.isEmpty { return false }
            return true
        } catch {
            return false
        }
    }
    
    public func checkIfGitIgnored(fileURLs: [URL]) async -> [URL] {
        if noCheck { return [] }
        let filePaths = fileURLs.map { "\"\($0.path)\"" }.joined(separator: " ")
        guard let firstFileURL = fileURLs.first else { return [] }
        let terminal = Terminal()
        guard let gitFolderURL = gitFolderURL(forFileURL: firstFileURL) else {
            return []
        }
        do {
            let result = try await terminal.runCommand(
                "/bin/bash",
                arguments: ["-c", "git check-ignore \(filePaths)"],
                currentDirectoryURL: gitFolderURL,
                environment: [:]
            )
            return result
                .split(whereSeparator: \.isNewline)
                .map(String.init)
                .compactMap(URL.init(fileURLWithPath:))
        } catch {
            return []
        }
    }
}

func gitFolderURL(forFileURL fileURL: URL) -> URL? {
    var currentURL = fileURL
    let fileManager = FileManager.default
    while currentURL.path != "/" {
        let gitFolderURL = currentURL.appendingPathComponent(".git")
        if fileManager.fileExists(atPath: gitFolderURL.path) {
            return currentURL
        }
        currentURL = currentURL.deletingLastPathComponent()
    }
    return nil
}

