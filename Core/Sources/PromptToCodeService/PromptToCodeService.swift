import CopilotModel
import CopilotService
import Foundation
import OpenAIService

public final class PromptToCodeService: ObservableObject {
    var designatedPromptToCodeAPI: PromptToCodeAPI?
    var promptToCodeAPI: PromptToCodeAPI {
        designatedPromptToCodeAPI ?? OpenAIPromptToCodeAPI()
    }

    var runningAPI: PromptToCodeAPI?

    @Published public var oldCode: String?
    @Published public var code: String
    @Published public var isResponding: Bool = false
    @Published public var description: String = ""
    @Published public var isContinuous = false
    public var oldDescription: String?
    public var canRevert: Bool { oldCode != nil }
    public var selectionRange: CursorRange
    public var language: CopilotLanguage
    public var indentSize: Int
    public var usesTabsForIndentation: Bool

    public init(
        code: String,
        selectionRange: CursorRange,
        language: CopilotLanguage,
        identSize: Int,
        usesTabsForIndentation: Bool
    ) {
        self.code = code
        self.selectionRange = selectionRange
        self.language = language
        indentSize = identSize
        self.usesTabsForIndentation = usesTabsForIndentation
    }

    public func modifyCode(prompt: String) async throws {
        let api = promptToCodeAPI
        runningAPI = api
        isResponding = true
        let toBeModified = code
        oldDescription = description
        oldCode = code
        code = ""
        description = ""
        defer { isResponding = false }
        do {
            let stream = try await api.modifyCode(
                code: toBeModified,
                language: language,
                indentSize: indentSize,
                usesTabsForIndentation: usesTabsForIndentation,
                requirement: prompt
            )
            for try await fragment in stream {
                Task { @MainActor in
                    code = fragment.code
                    description = fragment.description
                }
            }
        } catch is CancellationError {
            return
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                return
            }

            if let oldCode {
                code = oldCode
            }
            if let oldDescription {
                description = oldDescription
            }
            oldCode = nil
            oldDescription = nil
            throw error
        }
    }

    public func revert() {
        guard let oldCode = oldCode else { return }
        code = oldCode
        if let oldDescription {
            description = oldDescription
        }
        self.oldCode = nil
        oldDescription = nil
    }

    public func generateCompletion() -> CopilotCompletion {
        .init(
            text: code,
            position: selectionRange.start,
            uuid: UUID().uuidString,
            range: selectionRange,
            displayText: code
        )
    }

    public func stopResponding() {
        runningAPI?.stopResponding()
        isResponding = false
    }
}

protocol PromptToCodeAPI {
    func modifyCode(
        code: String,
        language: CopilotLanguage,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        requirement: String
    ) async throws -> AsyncThrowingStream<(code: String, description: String), Error>

    func stopResponding()
}

final class OpenAIPromptToCodeAPI: PromptToCodeAPI {
    var service: (any ChatGPTServiceType)?

    func stopResponding() {
        Task {
            await service?.stopReceivingMessage()
        }
    }

    func modifyCode(
        code: String,
        language: CopilotLanguage,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        requirement: String
    ) async throws -> AsyncThrowingStream<(code: String, description: String), Error> {
        let userPreferredLanguage = UserDefaults.shared.value(for: \.chatGPTLanguage)
        let textLanguage = userPreferredLanguage.isEmpty ? "" : "in \(userPreferredLanguage)"

        let prompt = {
            let indentRule = usesTabsForIndentation ? "\(indentSize) tabs" : "\(indentSize) spaces"
            if code.isEmpty {
                return """
                You are a senior programer in writing code in \(language.rawValue).

                Please write a piece of code that meets my requirements. The indentation should be \(
                    indentRule
                ).

                Please reply to me start with the code block, followed by a short description in 1-3 sentences about what you did \(
                    textLanguage
                ).
                """
            } else {
                return """
                You are a senior programer in writing code in \(language.rawValue).

                Please mutate the following code with my requirements. The indentation should be \(
                    indentRule
                ).

                Please reply to me start with the code block followed by a short description about what you did in 1-3 sentences \(
                    textLanguage
                ).

                ```
                \(code)
                ```
                """
            }
        }()

        let chatGPTService = ChatGPTService(systemPrompt: prompt)
        service = chatGPTService
        let stream = try await chatGPTService.send(content: requirement)
        return .init { continuation in
            Task {
                var content = ""
                do {
                    for try await fragment in stream {
                        content.append(fragment)
                        continuation.yield(extractCodeAndDescription(from: content))
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

final class CopilotPromptToCodeAPI: PromptToCodeAPI {
    func stopResponding() {
        fatalError()
    }

    func modifyCode(
        code: String,
        language: CopilotLanguage,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        requirement: String
    ) async throws -> AsyncThrowingStream<(code: String, description: String), Error> {
        fatalError()
    }
}
