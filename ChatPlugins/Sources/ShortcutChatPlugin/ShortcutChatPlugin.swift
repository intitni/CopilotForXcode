import ChatBasic
import Foundation
import Terminal

public final class ShortcutChatPlugin: ChatPlugin {
    public static var id: String { "com.intii.shortcut" }
    public static var command: String { "shortcut" }
    public static var name: String { "Shortcut" }
    public static var description: String { """
    Run a shortcut and use message content as input. You need to provide the shortcut name as an argument, for example, `/shortcut(Shortcut Name)`.
    """ }

    let terminal: TerminalType

    init(terminal: TerminalType) {
        self.terminal = terminal
    }

    public init() {
        terminal = Terminal()
    }

    public func send(_ request: Request) async -> AsyncThrowingStream<Response, any Error> {
        return .init { continuation in
            let task = Task {
                let id = "\(Self.command)-\(UUID().uuidString)"

                guard let shortcutName = request.arguments.first, !shortcutName.isEmpty else {
                    continuation.yield(.content(.text(
                        "Please provide the shortcut name in format: `/\(Self.command)(shortcut name)`"
                    )))
                    return
                }

                var input = String(request.text).trimmingCharacters(in: .whitespacesAndNewlines)
                if input.isEmpty {
                    // if no input detected, use the previous message as input
                    input = request.history.last?.content ?? ""
                }

                do {
                    continuation.yield(.startAction(
                        id: "run",
                        task: "Run shortcut `\(shortcutName)`"
                    ))

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

                    continuation.yield(.startAction(
                        id: "run",
                        task: "Run shortcut \(shortcutName)"
                    ))

                    do {
                        let result = try await terminal.runCommand(
                            shell,
                            arguments: ["-i", "-l", "-c", command],
                            currentDirectoryURL: nil,
                            environment: [:]
                        )
                        continuation.yield(.finishAction(id: "run", result: .success(result)))
                    } catch {
                        continuation.yield(.finishAction(
                            id: "run",
                            result: .failure(error.localizedDescription)
                        ))
                        throw error
                    }

                    await Task.yield()
                    try Task.checkCancellation()

                    if FileManager.default.fileExists(atPath: temporaryOutputFileURL.path) {
                        let data = try Data(contentsOf: temporaryOutputFileURL)
                        if let text = String(data: data, encoding: .utf8) {
                            var response = text
                            if response.isEmpty {
                                response = "Finished"
                            }
                            continuation.yield(.content(.text(response)))
                        } else {
                            let content = """
                            [View File](\(temporaryOutputFileURL))
                            """
                            continuation.yield(.content(.text(content)))
                        }
                    } else {
                        continuation.yield(.content(.text("Finished")))
                    }

                } catch {
                    continuation.yield(.content(.text(error.localizedDescription)))
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

