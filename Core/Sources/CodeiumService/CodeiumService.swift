import Foundation
import LanguageClient
import LanguageServerProtocol
import Logger
import SuggestionModel

public protocol CodeiumSuggestionServiceType {
    func getCompletions(
        fileURL: URL,
        content: String,
        cursorPosition: CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        ignoreSpaceOnlySuggestions: Bool
    ) async throws -> [CodeSuggestion]
    func notifyAccepted(_ suggestion: CodeSuggestion) async
    func notifyOpenTextDocument(fileURL: URL, content: String) async throws
    func notifyChangeTextDocument(fileURL: URL, content: String) async throws
    func notifyCloseTextDocument(fileURL: URL) async throws
    func cancelRequest() async
}

enum CodeiumError: Error, LocalizedError {
    case languageServerNotInstalled
    case languageServerOutdated
    case languageServiceIsInstalling

    var errorDescription: String? {
        switch self {
        case .languageServerNotInstalled:
            return "Language server is not installed. Please install it in the host app."
        case .languageServerOutdated:
            return "Language server is outdated. Please update it in the host app or update the extension."
        case .languageServiceIsInstalling:
            return "Language service is installing, please try again later."
        }
    }
}

public class CodeiumSuggestionService {
    static let sessionId = UUID().uuidString
    let projectRootURL: URL
    var server: CodeiumLSP?
    var heartbeatTask: Task<Void, Error>?
    var requestCounter: UInt64 = 0
    var cancellationCounter: UInt64 = 0
    let openedDocumentPool = OpenedDocumentPool()
    let onServiceLaunched: () -> Void

    let languageServerURL: URL
    let supportURL: URL

    let authService = CodeiumAuthService()

    var xcodeVersion = "14.0.0"
    var languageServerVersion = CodeiumInstallationManager.latestSupportedVersion

    init(designatedServer: CodeiumLSP) {
        projectRootURL = URL(fileURLWithPath: "/")
        server = designatedServer
        onServiceLaunched = {}
        languageServerURL = URL(fileURLWithPath: "/")
        supportURL = URL(fileURLWithPath: "/")
    }

    public init(projectRootURL: URL, onServiceLaunched: @escaping () -> Void) throws {
        self.projectRootURL = projectRootURL
        self.onServiceLaunched = onServiceLaunched
        let urls = try CodeiumSuggestionService.createFoldersIfNeeded()
        languageServerURL = urls.executableURL.appendingPathComponent("language_server")
        supportURL = urls.supportURL
        Task {
            try await setupServerIfNeeded()
        }
    }

    @discardableResult
    func setupServerIfNeeded() async throws -> CodeiumLSP {
        if let server { return server }

        let binaryManager = CodeiumInstallationManager()
        let installationStatus = binaryManager.checkInstallation()
        switch installationStatus {
        case let .installed(version), let .unsupported(version, _):
            languageServerVersion = version
        case .notInstalled:
            throw CodeiumError.languageServerNotInstalled
        case let .outdated(version, _):
            languageServerVersion = version
            throw CodeiumError.languageServerOutdated
        }

        let metadata = try getMetadata()
        xcodeVersion = (try? await getXcodeVersion()) ?? xcodeVersion
        let versionNumberSegmentCount = xcodeVersion.split(separator: ".").count
        if versionNumberSegmentCount == 2 {
            xcodeVersion += ".0"
        } else if versionNumberSegmentCount == 1 {
            xcodeVersion += ".0.0"
        }
        let tempFolderURL = FileManager.default.temporaryDirectory
        let managerDirectoryURL = tempFolderURL
            .appendingPathComponent("com.intii.CopilotForXcode")
            .appendingPathComponent(UUID().uuidString)
        if !FileManager.default.fileExists(atPath: managerDirectoryURL.path) {
            try FileManager.default.createDirectory(
                at: managerDirectoryURL,
                withIntermediateDirectories: true
            )
        }

        let server = CodeiumLanguageServer(
            languageServerExecutableURL: languageServerURL,
            managerDirectoryURL: managerDirectoryURL,
            supportURL: supportURL
        )

        server.terminationHandler = { [weak self] in
            self?.server = nil
            self?.heartbeatTask?.cancel()
            self?.requestCounter = 0
            self?.cancellationCounter = 0
            Logger.codeium.info("Language server is terminated, will be restarted when needed.")
        }

        server.launchHandler = { [weak self] in
            guard let self else { return }
            self.onServiceLaunched()
            self.heartbeatTask = Task { [weak self, metadata] in
                while true {
                    try Task.checkCancellation()
                    _ = try? await self?.server?.sendRequest(
                        CodeiumRequest.Heartbeat(requestBody: .init(metadata: metadata))
                    )
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                }
            }
        }

        self.server = server
        server.start()
        return server
    }

    public static func createFoldersIfNeeded() throws -> (
        applicationSupportURL: URL,
        gitHubCopilotURL: URL,
        executableURL: URL,
        supportURL: URL
    ) {
        let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent(
            Bundle.main
                .object(forInfoDictionaryKey: "APPLICATION_SUPPORT_FOLDER") as! String
        )

        if !FileManager.default.fileExists(atPath: supportURL.path) {
            try? FileManager.default
                .createDirectory(at: supportURL, withIntermediateDirectories: false)
        }
        let gitHubCopilotFolderURL = supportURL.appendingPathComponent("Codeium")
        if !FileManager.default.fileExists(atPath: gitHubCopilotFolderURL.path) {
            try? FileManager.default
                .createDirectory(at: gitHubCopilotFolderURL, withIntermediateDirectories: false)
        }
        let supportFolderURL = gitHubCopilotFolderURL.appendingPathComponent("support")
        if !FileManager.default.fileExists(atPath: supportFolderURL.path) {
            try? FileManager.default
                .createDirectory(at: supportFolderURL, withIntermediateDirectories: false)
        }
        let executableFolderURL = gitHubCopilotFolderURL.appendingPathComponent("executable")
        if !FileManager.default.fileExists(atPath: executableFolderURL.path) {
            try? FileManager.default
                .createDirectory(at: executableFolderURL, withIntermediateDirectories: false)
        }

        return (supportURL, gitHubCopilotFolderURL, executableFolderURL, supportFolderURL)
    }
}

extension CodeiumSuggestionService {
    func getMetadata() throws -> Metadata {
        guard let key = authService.key else {
            struct E: Error, LocalizedError {
                var errorDescription: String? { "Codeium not signed in." }
            }
            throw E()
        }
        return Metadata(
            ide_name: "xcode",
            ide_version: xcodeVersion,
            extension_version: languageServerVersion,
            api_key: key,
            session_id: CodeiumSuggestionService.sessionId,
            request_id: requestCounter
        )
    }

    func getRelativePath(of fileURL: URL) -> String {
        let filePath = fileURL.path
        let rootPath = projectRootURL.path
        if let range = filePath.range(of: rootPath),
           range.lowerBound == filePath.startIndex
        {
            let relativePath = filePath.replacingCharacters(
                in: filePath.startIndex..<range.upperBound,
                with: ""
            )
            return relativePath
        }
        return filePath
    }
}

extension CodeiumSuggestionService: CodeiumSuggestionServiceType {
    public func getCompletions(
        fileURL: URL,
        content: String,
        cursorPosition: CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        ignoreSpaceOnlySuggestions: Bool
    ) async throws -> [CodeSuggestion] {
        requestCounter += 1
        let languageId = languageIdentifierFromFileURL(fileURL)

        let relativePath = getRelativePath(of: fileURL)

        let request = CodeiumRequest.GetCompletion(requestBody: .init(
            metadata: try getMetadata(),
            document: .init(
                absolute_path: fileURL.path,
                relative_path: relativePath,
                text: content,
                editor_language: languageId.rawValue,
                language: .init(codeLanguage: languageId),
                cursor_position: .init(
                    row: cursorPosition.line,
                    col: cursorPosition.character
                )
            ),
            editor_options: .init(tab_size: indentSize, insert_spaces: !usesTabsForIndentation),
            other_documents: openedDocumentPool.getOtherDocuments(exceptURL: fileURL)
                .map { openedDocument in
                    let languageId = languageIdentifierFromFileURL(openedDocument.url)
                    return .init(
                        absolute_path: openedDocument.url.path,
                        relative_path: openedDocument.relativePath,
                        text: openedDocument.content,
                        editor_language: languageId.rawValue,
                        language: .init(codeLanguage: languageId)
                    )
                }
        ))
        
        if request.requestBody.metadata.request_id <= cancellationCounter {
            throw CancellationError()
        }

        let result = try await (try await setupServerIfNeeded()).sendRequest(request)
        
        if request.requestBody.metadata.request_id <= cancellationCounter {
            throw CancellationError()
        }

        return result.completionItems?.filter { item in
            if ignoreSpaceOnlySuggestions {
                return !item.completion.text.allSatisfy { $0.isWhitespace || $0.isNewline }
            }
            return true
        }.map { item in
            CodeSuggestion(
                text: item.completion.text,
                position: cursorPosition,
                uuid: item.completion.completionId,
                range: CursorRange(
                    start: .init(
                        line: item.range.startPosition?.row.flatMap(Int.init) ?? 0,
                        character: item.range.startPosition?.col.flatMap(Int.init) ?? 0
                    ),
                    end: .init(
                        line: item.range.endPosition?.row.flatMap(Int.init) ?? 0,
                        character: item.range.endPosition?.col.flatMap(Int.init) ?? 0
                    )
                ),
                displayText: item.completion.text
            )
        } ?? []
    }
    
    public func cancelRequest() async {
        cancellationCounter = requestCounter
    }

    public func notifyAccepted(_ suggestion: CodeSuggestion) async {
        _ = try? await (try setupServerIfNeeded())
            .sendRequest(CodeiumRequest.AcceptCompletion(requestBody: .init(
                metadata: getMetadata(),
                completion_id: suggestion.uuid
            )))
    }

    public func notifyOpenTextDocument(fileURL: URL, content: String) async throws {
        let relativePath = getRelativePath(of: fileURL)
        openedDocumentPool.openDocument(
            url: fileURL,
            relativePath: relativePath,
            content: content
        )
    }

    public func notifyChangeTextDocument(fileURL: URL, content: String) async throws {
        let relativePath = getRelativePath(of: fileURL)
        openedDocumentPool.updateDocument(
            url: fileURL,
            relativePath: relativePath,
            content: content
        )
    }

    public func notifyCloseTextDocument(fileURL: URL) async throws {
        openedDocumentPool.closeDocument(url: fileURL)
    }
}

func getXcodeVersion() async throws -> String {
    let task = Process()
    task.launchPath = "/usr/bin/xcodebuild"
    task.arguments = ["-version"]
    let outpipe = Pipe()
    task.standardOutput = outpipe
    task.standardError = Pipe()
    return try await withUnsafeThrowingContinuation { continuation in
        do {
            task.terminationHandler = { _ in
                do {
                    if let data = try outpipe.fileHandleForReading.readToEnd(),
                       let content = String(data: data, encoding: .utf8)
                    {
                        let firstLine = content.split(separator: "\n").first ?? ""
                        var version = firstLine.replacingOccurrences(of: "Xcode ", with: "")
                        if version.isEmpty {
                            version = "14.0"
                        }
                        continuation.resume(returning: version)
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

