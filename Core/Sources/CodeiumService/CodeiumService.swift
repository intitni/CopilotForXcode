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
}

enum CodeiumError: Error, LocalizedError {
    case languageServerNotInstalled

    var errorDescription: String? {
        switch self {
        case .languageServerNotInstalled:
            return "Language server is not installed."
        }
    }
}

let token = ""

public class CodeiumSuggestionService {
    static let sessionId = UUID().uuidString
    let projectRootURL: URL
    var server: CodeiumLSP?
    var heartbeatTask: Task<Void, Error>?
    var requestCounter: UInt64 = 0
    let openedDocumentPool = OpenedDocumentPool()
    let onServiceLaunched: () -> Void

    let languageServerURL: URL
    let supportURL: URL

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
        guard FileManager.default.fileExists(atPath: languageServerURL.path) else {
            throw CodeiumError.languageServerNotInstalled
        }
        try setupServerIfNeeded()
    }

    @discardableResult
    func setupServerIfNeeded() throws -> CodeiumLSP {
        if let server { return server }
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
            Logger.codeium.info("Language server is terminated, will be restarted when needed.")
        }

        server.launchHandler = { [weak self] in
            guard let self else { return }
            let metadata = self.getMetadata()
            self.onServiceLaunched()
            self.heartbeatTask = Task { [weak self] in
                while true {
                    try Task.checkCancellation()
                    _ = try? await self?.server?.sendRequest(
                        CodeiumRequest.Heartbeat(requestBody: .init(metadata: metadata))
                    )
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                }
            }
        }

        server.start()
        self.server = server
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
    func getMetadata() -> Metadata {
        Metadata(
            ide_name: "jetbrains",
            ide_version: "14.3",
            extension_name: "Copilot for Xcode",
            extension_version: "14.0.0",
            api_key: token,
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
            metadata: getMetadata(),
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

        let result = try await (try setupServerIfNeeded()).sendRequest(request)

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

