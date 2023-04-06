import Environment
import Foundation
import OpenAIService
import Terminal

public actor TerminalChatPlugin: ChatPlugin {
    public static var command: String { "run" }
    public nonisolated var name: String { "Terminal" }

    let chatGPTService: any ChatGPTServiceType
    var terminal: TerminalType = Terminal()
    var isCancelled = false
    weak var delegate: ChatPluginDelegate?

    public init(inside chatGPTService: any ChatGPTServiceType, delegate: ChatPluginDelegate) {
        self.chatGPTService = chatGPTService
        self.delegate = delegate
    }

    public func send(content: String) async {
        delegate?.pluginDidStart(self)
        delegate?.pluginDidStartResponding(self)

        let id = "\(Self.command)-\(UUID().uuidString)"
        var message = ChatMessage(id: id, role: .assistant, content: "")
        var outputContent = "" {
            didSet {
                message.content = """
                ```
                \(outputContent)
                ```
                """
            }
        }

        do {
            let fileURL = try await Environment.fetchCurrentFileURL()
            let projectURL = try await Environment.fetchCurrentProjectRootURL(fileURL)

            await chatGPTService.mutateHistory { history in
                history.append(.init(role: .user, content: "Run command: \(content)"))
            }

            if isCancelled { throw CancellationError() }

            let output = terminal.streamCommand(
                "/bin/bash",
                arguments: ["-c", content],
                currentDirectoryPath: projectURL?.path ?? fileURL.path,
                environment: [
                    "PROJECT_ROOT": projectURL?.path ?? fileURL.path,
                    "FILE_PATH": fileURL.path,
                ]
            )

            for try await content in output {
                if isCancelled { throw CancellationError() }
                await chatGPTService.mutateHistory { history in
                    if history.last?.id == id {
                        history.removeLast()
                    }
                    outputContent += content
                    history.append(message)
                }
            }
            outputContent += "\n[finished]"
            await chatGPTService.mutateHistory { history in
                if history.last?.id == id {
                    history.removeLast()
                }
                history.append(message)
            }
        } catch let error as Terminal.TerminationError {
            outputContent += "\n[error: \(error.status)]"
            await chatGPTService.mutateHistory { history in
                if history.last?.id == id {
                    history.removeLast()
                }
                history.append(message)
            }
        } catch {
            outputContent += "\n[error: \(error.localizedDescription)]"
            await chatGPTService.mutateHistory { history in
                if history.last?.id == id {
                    history.removeLast()
                }
                history.append(message)
            }
        }

        delegate?.pluginDidEndResponding(self)
        delegate?.pluginDidEnd(self)
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
