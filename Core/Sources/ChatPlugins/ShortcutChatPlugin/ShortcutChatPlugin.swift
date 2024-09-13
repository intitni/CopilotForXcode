import ChatPlugin
import Foundation
import OpenAIService
import Parsing
import Terminal

public actor ShortcutChatPlugin: ChatPlugin {
    public static var command: String { "shortcut" }
    public nonisolated var name: String { "Shortcut" }

    let chatGPTService: any LegacyChatGPTServiceType
    var terminal: TerminalType = Terminal()
    var isCancelled = false
    weak var delegate: ChatPluginDelegate?

    public init(inside chatGPTService: any LegacyChatGPTServiceType, delegate: ChatPluginDelegate) {
        self.chatGPTService = chatGPTService
        self.delegate = delegate
    }

    public func send(content: String, originalMessage: String) async {
        delegate?.pluginDidStart(self)
        delegate?.pluginDidStartResponding(self)

        defer {
            delegate?.pluginDidEndResponding(self)
            delegate?.pluginDidEnd(self)
        }

        let id = "\(Self.command)-\(UUID().uuidString)"
        var message = ChatMessage(id: id, role: .assistant, content: "")

        var content = content[...]
        let firstParenthesisParser = PrefixThrough("(")
        let shortcutNameParser = PrefixUpTo(")")

        _ = try? firstParenthesisParser.parse(&content)
        let shortcutName = try? shortcutNameParser.parse(&content)
        _ = try? PrefixThrough(")").parse(&content)

        guard let shortcutName, !shortcutName.isEmpty else {
            message.content =
                "Please provide the shortcut name in format: `/\(Self.command)(shortcut name)`."
            await chatGPTService.memory.appendMessage(message)
            return
        }

        var input = String(content).trimmingCharacters(in: .whitespacesAndNewlines)
        if input.isEmpty {
            // if no input detected, use the previous message as input
            input = await chatGPTService.memory.history.last?.content ?? ""
            await chatGPTService.memory.appendMessage(.init(role: .user, content: originalMessage))
        } else {
            await chatGPTService.memory.appendMessage(.init(role: .user, content: originalMessage))
        }

        do {
            if isCancelled { throw CancellationError() }

            let env = ProcessInfo.processInfo.environment
            let shell = env["SHELL"] ?? "/bin/bash"
            let temporaryURL = FileManager.default.temporaryDirectory
            let temporaryInputFileURL = temporaryURL
                .appendingPathComponent("\(id)-input.txt")
            let temporaryOutputFileURL = temporaryURL
                .appendingPathComponent("\(id)-output")

            try input.write(to: temporaryInputFileURL, atomically: true, encoding: .utf8)

            let command = """
            shortcuts run "\(shortcutName)" \
            -i "\(temporaryInputFileURL.path)" \
            -o "\(temporaryOutputFileURL.path)"
            """

            _ = try await terminal.runCommand(
                shell,
                arguments: ["-i", "-l", "-c", command],
                currentDirectoryURL: nil,
                environment: [:]
            )

            await Task.yield()

            if FileManager.default.fileExists(atPath: temporaryOutputFileURL.path) {
                let data = try Data(contentsOf: temporaryOutputFileURL)
                if let text = String(data: data, encoding: .utf8) {
                    message.content = text
                    if text.isEmpty {
                        message.content = "Finished"
                    }
                    await chatGPTService.memory.appendMessage(message)
                } else {
                    message.content = """
                    [View File](\(temporaryOutputFileURL))
                    """
                    await chatGPTService.memory.appendMessage(message)
                }

                return
            }

            message.content = "Finished"
            await chatGPTService.memory.appendMessage(message)
        } catch {
            message.content = error.localizedDescription
            if error.localizedDescription.isEmpty {
                message.content = "Error"
            }
            await chatGPTService.memory.appendMessage(message)
        }
    }

    public func cancel() async {
        isCancelled = true
        await terminal.terminate()
    }

    public func stopResponding() async {
        isCancelled = true
        await terminal.terminate()
    }
}

