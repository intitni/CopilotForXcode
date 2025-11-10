import ChatBasic
import Foundation
import Terminal
import XcodeInspector

public final class TerminalChatPlugin: ChatPlugin {
    public static var id: String { "com.intii.terminal" }
    public static var command: String { "shell" }
    public static var name: String { "Shell" }
    public static var description: String { """
    Run the command in the message from shell.

    You can use environment variable `$FILE_PATH` and `$PROJECT_ROOT` to access the current file path and project root.
    """ }

    let terminal: TerminalType

    init(terminal: TerminalType) {
        self.terminal = terminal
    }

    public init() {
        terminal = Terminal()
    }

    public func getTextContent(from request: Request) async
        -> AsyncStream<String>
    {
        return .init { continuation in
            let task = Task {
                do {
                    let fileURL = XcodeInspector.shared.realtimeActiveDocumentURL
                    let projectURL = XcodeInspector.shared.realtimeActiveProjectURL

                    var environment = [String: String]()
                    if let fileURL {
                        environment["FILE_PATH"] = fileURL.path
                    }
                    if let projectURL {
                        environment["PROJECT_ROOT"] = projectURL.path
                    }

                    try Task.checkCancellation()

                    let env = ProcessInfo.processInfo.environment
                    let shell = env["SHELL"] ?? "/bin/bash"

                    let output = terminal.streamCommand(
                        shell,
                        arguments: ["-i", "-l", "-c", request.text],
                        currentDirectoryURL: projectURL,
                        environment: environment
                    )

                    var accumulatedOutput = ""
                    for try await content in output {
                        try Task.checkCancellation()
                        accumulatedOutput += content
                        continuation.yield(accumulatedOutput)
                    }
                } catch let error as Terminal.TerminationError {
                    let errorMessage = "\n\n[error: \(error.reason)]"
                    continuation.yield(errorMessage)
                } catch {
                    let errorMessage = "\n\n[error: \(error.localizedDescription)]"
                    continuation.yield(errorMessage)
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
                Task {
                    await self.terminal.terminate()
                }
            }
        }
    }

    public func sendForTextResponse(_ request: Request) async
        -> AsyncThrowingStream<String, any Error>
    {
        let stream = await getTextContent(from: request)
        return .init { continuation in
            let task = Task {
                continuation.yield("Executing command: `\(request.text)`\n\n")
                continuation.yield("```console\n")
                for await text in stream {
                    try Task.checkCancellation()
                    continuation.yield(text)
                }
                continuation.yield("\n```\n")
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func formatContent(_ content: Response.Content) -> Response.Content {
        switch content {
        case let .text(content):
            return .text("""
            ```console
            \(content)
            ```
            """)
        }
    }

    public func sendForComplicatedResponse(_ request: Request) async
        -> AsyncThrowingStream<Response, any Error>
    {
        return .init { continuation in
            let task = Task {
                var updateTime = Date()

                continuation.yield(.startAction(id: "run", task: "Run `\(request.text)`"))

                let textStream = await getTextContent(from: request)
                var previousOutput = ""

                continuation.yield(.finishAction(
                    id: "run",
                    result: .success("Executed.")
                ))

                for await accumulatedOutput in textStream {
                    try Task.checkCancellation()

                    let newContent = accumulatedOutput.dropFirst(previousOutput.count)
                    previousOutput = accumulatedOutput

                    if !newContent.isEmpty {
                        if Date().timeIntervalSince(updateTime) > 60 * 2 {
                            continuation.yield(.startNewMessage)
                            continuation.yield(.startAction(
                                id: "run",
                                task: "Continue `\(request.text)`"
                            ))
                            continuation.yield(.finishAction(
                                id: "run",
                                result: .success("Executed.")
                            ))
                            continuation.yield(.content(.text("[continue]\n")))
                            updateTime = Date()
                        }

                        continuation.yield(.content(.text(String(newContent))))
                    }
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

