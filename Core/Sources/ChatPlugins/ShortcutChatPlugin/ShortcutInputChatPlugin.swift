import ChatPlugin
import Foundation
import OpenAIService
import Parsing
import Terminal

public actor ShortcutInputChatPlugin: ChatPlugin {
    public static var command: String { "shortcutInput" }
    public nonisolated var name: String { "Shortcut Input" }

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

        var content = content[...]
        let firstParenthesisParser = PrefixThrough("(")
        let shortcutNameParser = PrefixUpTo(")")

        _ = try? firstParenthesisParser.parse(&content)
        let shortcutName = try? shortcutNameParser.parse(&content)
        _ = try? PrefixThrough(")").parse(&content)

        guard let shortcutName, !shortcutName.isEmpty else {
            let id = "\(Self.command)-\(UUID().uuidString)"
            let reply = ChatMessage(
                id: id,
                role: .assistant,
                content: "Please provide the shortcut name in format: `/\(Self.command)(shortcut name)`."
            )
            await chatGPTService.memory.appendMessage(reply)
            return
        }

        var input = String(content).trimmingCharacters(in: .whitespacesAndNewlines)
        if input.isEmpty {
            // if no input detected, use the previous message as input
            input = await chatGPTService.memory.history.last?.content ?? ""
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
                    if text.isEmpty { return }
                    let stream = try await chatGPTService.send(content: text, summary: nil)
                    do {
                        for try await _ in stream {}
                    } catch {}
                } else {
                    let text = """
                    [View File](\(temporaryOutputFileURL))
                    """
                    let stream = try await chatGPTService.send(content: text, summary: nil)
                    do {
                        for try await _ in stream {}
                    } catch {}
                }

                return
            }
        } catch {
            let id = "\(Self.command)-\(UUID().uuidString)"
            let reply = ChatMessage(
                id: id,
                role: .assistant,
                content: error.localizedDescription
            )
            await chatGPTService.memory.appendMessage(reply)
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

