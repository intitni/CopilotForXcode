import Foundation
import LanguageClient
import LanguageServerProtocol
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

public class CodeiumSuggestionService: CodeiumSuggestionServiceType {
    let projectRootURL: URL
    var server: CodeiumLSP

    init(designatedServer: CodeiumLSP) {
        projectRootURL = URL(fileURLWithPath: "/")
        server = designatedServer
    }

    public init(projectRootURL: URL) throws {
        self.projectRootURL = projectRootURL

        let urls = try CodeiumSuggestionService.createFoldersIfNeeded()
        let languageServerURL = urls.executableURL.appendingPathComponent("language_server")
        guard FileManager.default.fileExists(atPath: languageServerURL.path) else {
            throw CodeiumError.languageServerNotInstalled
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
            supportURL: urls.supportURL
        )

        self.server = server
        server.terminationHandler = {
            print("terminated")
        }
        server.launchHandler = {
            print("launched")
        }
        server.start()
    }

    public func getCompletions(
        fileURL: URL,
        content: String,
        cursorPosition: CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        ignoreSpaceOnlySuggestions: Bool
    ) async throws -> [CodeSuggestion] {
        let languageId = languageIdentifierFromFileURL(fileURL)

        let relativePath = {
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
        }()

        let request = CodeiumRequest.GetCompletion(requestBody: .init(
            metadata: .init(
                ide_name: "jetbrains", ide_version: "14.3", extension_name: "Copilot for Xcode",
                extension_version: "14.0.0",
                api_key: token,
                session_id: UUID().uuidString, request_id: 100
            ),
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
            other_documents: []
        ))

        let result = try await server.sendRequest(request)

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

