import SuggestionModel
import GitHubCopilotService
import Foundation
import OpenAIService

final class OpenAIPromptToCodeAPI: PromptToCodeAPI {
    var service: (any ChatGPTServiceType)?

    func stopResponding() {
        Task {
            await service?.stopReceivingMessage()
        }
    }

    func modifyCode(
        code: String,
        language: CodeLanguage,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        requirement: String,
        projectRootURL: URL,
        fileURL: URL,
        allCode: String,
        extraSystemPrompt: String?
    ) async throws -> AsyncThrowingStream<(code: String, description: String), Error> {
        let userPreferredLanguage = UserDefaults.shared.value(for: \.chatGPTLanguage)
        let textLanguage = userPreferredLanguage.isEmpty ? "" : "in \(userPreferredLanguage)"

        let prompt = {
            let indentRule = usesTabsForIndentation ? "\(indentSize) tabs" : "\(indentSize) spaces"
            if code.isEmpty {
                return """
                You are a senior programer in writing code in \(language.rawValue).
                
                File url: \(fileURL)
                
                \(extraSystemPrompt ?? "")

                Please write a piece of code that meets my requirements. The indentation should be \(
                    indentRule
                ).

                Please reply to me start with the code block, followed by a clear and concise description in 1-3 sentences about what you did \(
                    textLanguage
                ).
                """
            } else {
                return """
                # Description
                
                You are a senior programer in writing code in \(language.rawValue).
                
                File url: \(fileURL)
                
                \(extraSystemPrompt ?? "")

                Please mutate the following code fragment with my requirements. Keep the original indentation. Do not add comments unless told to.

                Please reply to me start with the code block followed by a clear and concise description about what you did in 1-3 sentences \(
                    textLanguage
                ).

                # Code
                
                ```\(language.rawValue)
                \(code)
                ```
                """
            }
        }()

        let chatGPTService = ChatGPTService(systemPrompt: prompt, temperature: 0.3)
        service = chatGPTService
        let stream = try await chatGPTService.send(content: requirement)
        return .init { continuation in
            Task {
                var content = ""
                var extracted = extractCodeAndDescription(from: content)
                do {
                    for try await fragment in stream {
                        content.append(fragment)
                        extracted = extractCodeAndDescription(from: content)
                        if !content.isEmpty, extracted.code.isEmpty {
                            continuation.yield((code: content, description: ""))
                        } else {
                            continuation.yield(extracted)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func extractCodeAndDescription(from content: String) -> (code: String, description: String) {
        func extractCodeFromMarkdown(_ markdown: String) -> (code: String, endIndex: Int)? {
            let codeBlockRegex = try! NSRegularExpression(
                pattern: #"```(?:\w+)?[\n]([\s\S]+?)[\n]```"#,
                options: .dotMatchesLineSeparators
            )
            let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
            if let match = codeBlockRegex.firstMatch(in: markdown, options: [], range: range) {
                let codeBlockRange = Range(match.range(at: 1), in: markdown)!
                return (String(markdown[codeBlockRange]), match.range(at: 0).upperBound)
            }

            let incompleteCodeBlockRegex = try! NSRegularExpression(
                pattern: #"```(?:\w+)?[\n]([\s\S]+?)$"#,
                options: .dotMatchesLineSeparators
            )
            let range2 = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
            if let match = incompleteCodeBlockRegex.firstMatch(
                in: markdown,
                options: [],
                range: range2
            ) {
                let codeBlockRange = Range(match.range(at: 1), in: markdown)!
                return (String(markdown[codeBlockRange]), match.range(at: 0).upperBound)
            }
            return nil
        }

        guard let (code, endIndex) = extractCodeFromMarkdown(content) else {
            return ("", "")
        }

        func extractDescriptionFromMarkdown(_ markdown: String, startIndex: Int) -> String {
            let startIndex = markdown.index(markdown.startIndex, offsetBy: startIndex)
            guard startIndex < markdown.endIndex else { return "" }
            let range = startIndex..<markdown.endIndex
            let description = String(markdown[range])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return description
        }

        let description = extractDescriptionFromMarkdown(content, startIndex: endIndex)

        return (code, description)
    }
}

