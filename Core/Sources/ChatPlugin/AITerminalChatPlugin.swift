import Foundation
import OpenAIService
import Terminal

public actor AITerminalChatPlugin: ChatPlugin {
    public static var command: String { "airun" }
    public nonisolated var name: String { "AI Terminal" }

    let chatGPTService: any LegacyChatGPTServiceType
    var terminal: TerminalType = Terminal()
    var isCancelled = false
    weak var delegate: ChatPluginDelegate?
    var isStarted = false
    var command: String?

    public init(inside chatGPTService: any LegacyChatGPTServiceType, delegate: ChatPluginDelegate) {
        self.chatGPTService = chatGPTService
        self.delegate = delegate
    }

    public func send(content: String, originalMessage: String) async {
        if !isStarted {
            isStarted = true
            delegate?.pluginDidStart(self)
        }

        do {
            if let command {
                await chatGPTService.memory.mutateHistory { history in
                    history.append(.init(role: .user, content: content))
                }
                delegate?.pluginDidStartResponding(self)
                if isCancelled { return }
                switch try await checkConfirmation(content: content) {
                case .confirmation:
                    delegate?.pluginDidEndResponding(self)
                    delegate?.pluginDidEnd(self)
                    delegate?.shouldStartAnotherPlugin(
                        TerminalChatPlugin.self,
                        withContent: command
                    )
                case .cancellation:
                    delegate?.pluginDidEndResponding(self)
                    delegate?.pluginDidEnd(self)
                    await chatGPTService.memory.mutateHistory { history in
                        history.append(.init(role: .assistant, content: "Cancelled"))
                    }
                case .modification:
                    let result = try await modifyCommand(command: command, requirement: content)
                    self.command = result
                    delegate?.pluginDidEndResponding(self)
                    await chatGPTService.memory.mutateHistory { history in
                        history.append(.init(role: .assistant, content: """
                        Should I run this command? You can instruct me to modify it again.
                        ```
                        \(result)
                        ```
                        """))
                    }
                case .other:
                    delegate?.pluginDidEndResponding(self)
                    await chatGPTService.memory.mutateHistory { history in
                        history.append(.init(
                            role: .assistant,
                            content: "Sorry, I don't understand. Do you want me to run it?"
                        ))
                    }
                }
            } else {
                await chatGPTService.memory.mutateHistory { history in
                    history.append(.init(
                        role: .user,
                        content: originalMessage,
                        summary: "Run a command to \(content)")
                    )
                }
                delegate?.pluginDidStartResponding(self)
                let result = try await generateCommand(task: content)
                command = result
                if isCancelled { return }
                await chatGPTService.memory.mutateHistory { history in
                    history.append(.init(role: .assistant, content: """
                    Should I run this command? You can instruct me to modify it.
                    ```
                    \(result)
                    ```
                    """))
                }
                delegate?.pluginDidEndResponding(self)
            }
        } catch {
            await chatGPTService.memory.mutateHistory { history in
                history.append(.init(role: .assistant, content: error.localizedDescription))
            }
            delegate?.pluginDidEndResponding(self)
            delegate?.pluginDidEnd(self)
        }
    }

    public func cancel() async {
        isCancelled = true
        delegate?.pluginDidEndResponding(self)
        delegate?.pluginDidEnd(self)
    }

    public func stopResponding() async {}

    func generateCommand(task: String) async throws -> String {
        let p = """
        Available environment variables:
        - $PROJECT_ROOT: the root path of the project
        - $FILE_PATH: the currently editing file

        Current directory path is the project root.

        Generate a terminal command to solve the given task on macOS. If one command is not enough, you can use && to concatenate multiple commands.

        The reply should contains only the command and nothing else.
        """

        return extractCodeFromMarkdown(try await askChatGPT(
            systemPrompt: p,
            question: "the task is: \"\(task)\""
        ) ?? "")
    }

    func modifyCommand(command: String, requirement: String) async throws -> String {
        let p = """
        Available environment variables:
        - $PROJECT_ROOT: the root path of the project
        - $FILE_PATH: the currently editing file

        Current directory path is the project root.

        Modify the terminal command `\(
            command
        )` in macOS with the given requirement. If one command is not enough, you can use && to concatenate multiple commands.

        The reply should contains only the command and nothing else.
        """

        return extractCodeFromMarkdown(try await askChatGPT(
            systemPrompt: p,
            question: "The requirement is: \"\(requirement)\""
        ) ?? "")
    }

    func checkConfirmation(content: String) async throws -> Tone {
        let p = """
        Check the tone of the content, reply with only the number representing the tone.

        1: If the given content is a phrase or sentence that considered a confirmation to run a command.

        For example: "Yes", "Confirm", "True", "Run it". It can be in any language.

        2: If the given content is a phrase or sentence that considered a cancellation to run a command.

        For example: "No", "Cancel", "False", "Don't run it", "Stop". It can be in any language.

        3: If the given content is a modification request.

        For example: "Use echo instead", "Remove the argument", "Change to path".

        4: Everything else.
        """

        let result = try await askChatGPT(
            systemPrompt: p,
            question: "The content is: \"\(content)\""
        )
        let tone = result.flatMap(Int.init).flatMap(Tone.init(rawValue:)) ?? .other
        return tone
    }

    enum Tone: Int {
        case confirmation = 1
        case cancellation = 2
        case modification = 3
        case other = 4
    }

    func extractCodeFromMarkdown(_ markdown: String) -> String {
        let codeBlockRegex = try! NSRegularExpression(
            pattern: "```[\n](.*?)[\n]```",
            options: .dotMatchesLineSeparators
        )
        let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
        guard let match = codeBlockRegex.firstMatch(in: markdown, options: [], range: range) else {
            return markdown
                .replacingOccurrences(of: "`", with: "")
                .replacingOccurrences(of: "\n", with: "")
        }
        let codeBlockRange = Range(match.range(at: 1), in: markdown)!
        return String(markdown[codeBlockRange])
    }
}
