import SuggestionModel
import GitHubCopilotService
import Foundation
import OpenAIService

final class CopilotPromptToCodeAPI: PromptToCodeAPI {
    var task: Task<Void, Never>?

    func stopResponding() {
        task?.cancel()
    }

    func modifyCode(
        code: String,
        language: CopilotLanguage,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        requirement: String,
        projectRootURL: URL,
        fileURL: URL,
        allCode: String,
        extraSystemPrompt: String?
    ) async throws -> AsyncThrowingStream<(code: String, description: String), Error> {
        let copilotService = CopilotSuggestionService(projectRootURL: projectRootURL)
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
        
        func convertToComment(_ s: String) -> String {
            s.split(separator: "\n").map { "// \($0)" }.joined(separator: "\n")
        }
        
        let comment = """
        // A file to refactor the following code
        //
        // Code:
        // ```
        \(convertToComment(code))
        // ```
        //
        // Requirements:
        \(convertToComment((extraSystemPrompt ?? "\n") + requirement))
        //
        
        
        
        // end of file
        """
        let lineCount = comment.breakLines().count

        return .init { continuation in
            self.task = Task {
                do {
                    let result = try await copilotService.getCompletions(
                        fileURL: fileURL,
                        content: comment,
                        cursorPosition: .init(line: lineCount - 3, character: 0),
                        tabSize: indentSize,
                        indentSize: indentSize,
                        usesTabsForIndentation: usesTabsForIndentation,
                        ignoreSpaceOnlySuggestions: true
                    )
                    try Task.checkCancellation()
                    guard let first = result.first else { throw CancellationError() }
                    continuation.yield((first.text, ""))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

extension String {
    /// Break a string into lines.
    func breakLines() -> [String] {
        let lines = split(separator: "\n", omittingEmptySubsequences: false)
        var all = [String]()
        for (index, line) in lines.enumerated() {
            if index == lines.endIndex - 1 {
                all.append(String(line))
            } else {
                all.append(String(line) + "\n")
            }
        }
        return all
    }
}
