import Environment
import Foundation
import OpenAIService
import Terminal

public actor AITerminalChatPlugin: ChatPlugin {
    public static var command: String { "airun" }
    public nonisolated var name: String { "AI Terminal" }

    let chatGPTService: any ChatGPTServiceType
    var terminal: TerminalType = Terminal()
    var isCancelled = false
    weak var delegate: ChatPluginDelegate?
    var isStarted = false
    var command: String?

    public init(inside chatGPTService: any ChatGPTServiceType, delegate: ChatPluginDelegate) {
        self.chatGPTService = chatGPTService
        self.delegate = delegate
    }

    public func send(content: String) async {
        if !isStarted {
            isStarted = true
            delegate?.pluginDidStart(self)
        }

        do {
            if let command {
                await chatGPTService.mutateHistory { history in
                    history.append(.init(role: .user, content: content))
                }
                delegate?.pluginDidStartResponding(self)
                if isCancelled { return }
                if try await checkConfirmation(content: content) {
                    delegate?.pluginDidEndResponding(self)
                    delegate?.pluginDidEnd(self)
                    delegate?.shouldStartAnotherPlugin(
                        TerminalChatPlugin.self,
                        withContent: command
                    )
                } else {
                    delegate?.pluginDidEndResponding(self)
                    delegate?.pluginDidEnd(self)
                    await chatGPTService.mutateHistory { history in
                        history.append(.init(role: .assistant, content: "Cancelled"))
                    }
                }
            } else {
                await chatGPTService.mutateHistory { history in
                    history.append(.init(role: .user, content: "Run a command to \(content)"))
                }
                delegate?.pluginDidStartResponding(self)
                let result = try await generateCommand(task: content)
                command = result
                if isCancelled { return }
                await chatGPTService.mutateHistory { history in
                    history.append(.init(role: .assistant, content: """
                    Confirm to run?
                    ```
                    \(result)
                    ```
                    """))
                }
                delegate?.pluginDidEndResponding(self)
            }
        } catch {
            await chatGPTService.mutateHistory { history in
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

    func callAIFunction(
        function: String,
        args: [Any?],
        description: String
    ) async throws -> String {
        let args = args.map { arg -> String in
            if let arg = arg {
                return String(describing: arg)
            } else {
                return "None"
            }
        }
        let argsString = args.joined(separator: ", ")
        let service = ChatGPTService(
            systemPrompt: "You are now the following python function: ```# \(description)\n\(function)```\n\nOnly respond with your `return` value."
        )
        return try await service.sendAndWait(content: argsString)
    }

    func generateCommand(task: String) async throws -> String {
        let f = "def generate_terminal_command(task: str) -> string:"
        let d = """
        Available environment variables:
        - $PROJECT_ROOT: the root path of the project
        - $FILE_PATH: the currently editing file

        Current directory path is the project root.

        The return value should not be embedded in a markdown code block.

        Generate a terminal command to solve the given task on macOS. If one command is not enough, you can use && to concatenate multiple commands.
        """

        return try await callAIFunction(function: f, args: [task], description: d)
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }

    func checkConfirmation(content: String) async throws -> Bool {
        let f = "def check_confirmation(content: str) -> bool:"
        let d = """
        Check if the given content is a phrase or sentence that considered a confirmation to run a command.

        For example: "Yes", "Confirm", "True", "Run it". It can be in any language.
        """

        let result = try await callAIFunction(function: f, args: [content], description: d)
        return result.lowercased().contains("true")
    }
}
