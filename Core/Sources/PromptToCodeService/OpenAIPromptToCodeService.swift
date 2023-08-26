import Foundation
import OpenAIService
import Preferences
import SuggestionModel

public final class OpenAIPromptToCodeService: PromptToCodeServiceType {
    var service: (any ChatGPTServiceType)?
    
    public init() {}

    public func stopResponding() {
        Task { await service?.stopReceivingMessage() }
    }

    public func modifyCode(
        code: String,
        language: CodeLanguage,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        requirement: String,
        projectRootURL: URL,
        fileURL: URL,
        allCode: String,
        extraSystemPrompt: String?,
        generateDescriptionRequirement: Bool?
    ) async throws -> AsyncThrowingStream<(code: String, description: String), Error> {
        let userPreferredLanguage = UserDefaults.shared.value(for: \.chatGPTLanguage)
        let textLanguage = {
            if !UserDefaults.shared
                .value(for: \.promptToCodeGenerateDescriptionInUserPreferredLanguage)
            {
                return ""
            }
            return userPreferredLanguage.isEmpty ? "" : "in \(userPreferredLanguage)"
        }()

        let rule: String = {
            func generateDescription(index: Int) -> String {
                let generateDescription = generateDescriptionRequirement ?? UserDefaults.shared
                    .value(for: \.promptToCodeGenerateDescription)
                return generateDescription
                    ? """
                    \(index). After the code block, write a clear and concise description \
                    in 1-3 sentences about what you did in step 1\(textLanguage).
                    \(index + 1). Reply with the result.
                    """
                    : "\(index). Reply with the result."
            }
            switch language {
            case .builtIn(.markdown), .plaintext:
                if code.isEmpty {
                    return """
                    1. Write the content that meets my requirements.
                    2. Embed the new content in a markdown code block.
                    \(generateDescription(index: 3))
                    """
                } else {
                    return """
                    1. Do what I required.
                    2. Format the updated content to use the original indentation. Especially the first line.
                    3. Embed the updated content in a markdown code block.
                    4. You MUST never translate the content in the code block if it's not requested in the requirements.
                    \(generateDescription(index: 5))
                    """
                }
            default:
                if code.isEmpty {
                    return """
                    1. Write the code that meets my requirements.
                    2. Embed the code in a markdown code block.
                    \(generateDescription(index: 3))
                    """
                } else {
                    return """
                    1. Do what I required.
                    2. Format the updated code to use the original indentation. Especially the first line.
                    3. Embed the updated code in a markdown code block.
                    \(generateDescription(index: 4))
                    """
                }
            }
        }()

        let systemPrompt = {
            switch language {
            case .builtIn(.markdown), .plaintext:
                if code.isEmpty {
                    return """
                    You are good at writing in \(language.rawValue).
                    The active file is: \(fileURL.lastPathComponent).
                    \(extraSystemPrompt ?? "")

                    \(rule)
                    """
                } else {
                    return """
                    You are good at writing in \(language.rawValue).
                    The active file is: \(fileURL.lastPathComponent).
                    \(extraSystemPrompt ?? "")

                    \(rule)
                    """
                }
            default:
                if code.isEmpty {
                    return """
                    You are a senior programer in writing in \(language.rawValue).
                    The active file is: \(fileURL.lastPathComponent).
                    \(extraSystemPrompt ?? "")

                    \(rule)
                    """
                } else {
                    return """
                    You are a senior programer in writing in \(language.rawValue).
                    The active file is: \(fileURL.lastPathComponent).
                    \(extraSystemPrompt ?? "")

                    \(rule)
                    """
                }
            }
        }()

        let firstMessage: String? = {
            if code.isEmpty { return nil }
            switch language {
            case .builtIn(.markdown), .plaintext:
                return """
                ```
                \(code)
                ```
                """
            default:
                return """
                ```
                \(code)
                ```
                """
            }
        }()

        let secondMessage = """
        Requirements:###
        \(requirement)
        ###
        """

        let configuration =  UserPreferenceChatGPTConfiguration()
            .overriding(.init(temperature: 0))
        let memory = AutoManagedChatGPTMemory(
            systemPrompt: systemPrompt,
            configuration: configuration,
            functionProvider: NoChatGPTFunctionProvider()
        )
        let chatGPTService = ChatGPTService(
            memory: memory,
            configuration: configuration
        )
        service = chatGPTService
        if let firstMessage {
            await memory.mutateHistory { history in
                history.append(.init(role: .user, content: firstMessage))
            }
        }
        let stream = try await chatGPTService.send(content: secondMessage)
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

