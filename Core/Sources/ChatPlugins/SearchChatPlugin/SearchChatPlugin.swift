import ChatPlugin
import Environment
import Foundation
import OpenAIService

public actor SearchChatPlugin: ChatPlugin {
    public static var command: String { "search" }
    public nonisolated var name: String { "Search" }

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
        var reply = ChatMessage(id: id, role: .assistant, content: "Calculating...")

        await chatGPTService.mutateHistory { history in
            history.append(.init(role: .user, content: originalMessage, summary: content))
            history.append(reply)
        }

        do {
            let result = try await search(content)
            await chatGPTService.mutateHistory { history in
                if history.last?.id == id {
                    history.removeLast()
                }
                reply.content = result
                history.append(reply)
            }
        } catch {
            await chatGPTService.mutateHistory { history in
                if history.last?.id == id {
                    history.removeLast()
                }
                reply.content = error.localizedDescription
                history.append(reply)
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

