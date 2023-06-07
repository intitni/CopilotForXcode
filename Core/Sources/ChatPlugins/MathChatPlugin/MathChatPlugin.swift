import ChatPlugin
import Environment
import Foundation
import OpenAIService

/// Use Python to solve math problems.
public actor MathChatPlugin: ChatPlugin {
    public static var command: String { "math" }
    public nonisolated var name: String { "Math" }

    let chatGPTService: any ChatGPTServiceType
    var isCancelled = false
    weak var delegate: ChatPluginDelegate?

    public init(inside chatGPTService: any ChatGPTServiceType, delegate: ChatPluginDelegate) {
        self.chatGPTService = chatGPTService
        self.delegate = delegate
    }

    public func send(content: String, originalMessage: String) async {
        delegate?.pluginDidStart(self)
        delegate?.pluginDidStartResponding(self)

        let id = "\(Self.command)-\(UUID().uuidString)"
        async let translatedCalculating = translate(text: "Calculating...")
        async let translatedAnswer = translate(text: "Answer:")
        var reply = ChatMessage(id: id, role: .assistant, content: await translatedCalculating)

        await chatGPTService.mutateHistory { history in
            history.append(.init(role: .user, content: originalMessage, summary: content))
            history.append(reply)
        }

        do {
            let result = try await solveMathProblem(content)
            let formattedResult = "\(await translatedAnswer) \(result)"
            if !isCancelled {
                await chatGPTService.mutateHistory { history in
                    if history.last?.id == id {
                        history.removeLast()
                    }
                    reply.content = formattedResult
                    history.append(reply)
                }
            }
        } catch {
            if !isCancelled {
                await chatGPTService.mutateHistory { history in
                    if history.last?.id == id {
                        history.removeLast()
                    }
                    reply.content = error.localizedDescription
                    history.append(reply)
                }
            }
        }

        delegate?.pluginDidEndResponding(self)
        delegate?.pluginDidEnd(self)
    }

    public func cancel() async {
        isCancelled = true
    }

    public func stopResponding() async {
        isCancelled = true
    }
}

