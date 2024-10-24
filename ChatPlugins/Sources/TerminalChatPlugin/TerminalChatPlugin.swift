import ChatBasic
import Foundation
import Terminal
import XcodeInspector

public final class TerminalChatPlugin: ChatPlugin {
    public static var id: String { "com.intii.terminal" }
    public static var command: String { "run" }
    public static var name: String { "Terminal" }

    let terminal: TerminalType

    init(terminal: TerminalType) {
        self.terminal = terminal
    }

    public init() {
        terminal = Terminal()
    }

    public func formatContent(_ content: Response.Content) -> Response.Content {
        switch content {
        case let .text(content):
            return .text("""
            ```sh
            \(content)
            ```
            """)
        }
    }

    public func send(_ request: Request) async -> AsyncThrowingStream<Response, any Error> {
        return .init { continuation in
            let task = Task {
                var updateTime = Date()

                func streamOutput(_ content: String) {
                    defer { updateTime = Date() }
                    if Date().timeIntervalSince(updateTime) > 60 * 2 {
                        continuation.yield(.startNewMessage)
                        continuation.yield(.startAction(
                            id: "run",
                            task: "Continue `\(request.text)`"
                        ))
                        continuation.yield(.finishAction(
                            id: "run",
                            result: .success("Printing output...")
                        ))
                        continuation.yield(.content(.text("[continue]\n")))
                        continuation.yield(.content(.text(content)))
                    } else {
                        continuation.yield(.content(.text(content)))
                    }
                }

                do {
                    let fileURL = await XcodeInspector.shared.safe.realtimeActiveDocumentURL
                    let projectURL = await XcodeInspector.shared.safe.realtimeActiveProjectURL

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

                    continuation.yield(.startAction(id: "run", task: "Run `\(request.text)`"))

                    let output = terminal.streamCommand(
                        shell,
                        arguments: ["-i", "-l", "-c", request.text],
                        currentDirectoryURL: projectURL,
                        environment: environment
                    )

                    continuation.yield(.finishAction(
                        id: "run",
                        result: .success("Printing output...")
                    ))

                    for try await content in output {
                        try Task.checkCancellation()
                        streamOutput(content)
                    }
                } catch let error as Terminal.TerminationError {
                    continuation.yield(.content(.text("""

                    [error: \(error.reason)]
                    """)))
                } catch {
                    continuation.yield(.content(.text("""

                    [error: \(error.localizedDescription)]
                    """)))
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
}

