import ChatPlugin
import Foundation
import OpenAIService

public actor SearchChatPlugin: ChatPlugin {
    public static var command: String { "search" }
    public nonisolated var name: String { "Search" }

    let chatGPTService: any LegacyChatGPTServiceType
    var isCancelled = false
    weak var delegate: ChatPluginDelegate?

    public init(inside chatGPTService: any LegacyChatGPTServiceType, delegate: ChatPluginDelegate) {
        self.chatGPTService = chatGPTService
        self.delegate = delegate
    }

    public func send(content: String, originalMessage: String) async {
        delegate?.pluginDidStart(self)
        delegate?.pluginDidStartResponding(self)

        let id = "\(Self.command)-\(UUID().uuidString)"
        var reply = ChatMessage(id: id, role: .assistant, content: "")

        await chatGPTService.memory.appendMessage(.init(role: .user, content: originalMessage, summary: content))

        do {
            let (eventStream, cancelAgent) = try await search(content)

            var actions = [String]()
            var finishedActions = Set<String>()
            var message = ""

            for try await event in eventStream {
                guard !isCancelled else {
                    await cancelAgent()
                    break
                }
                switch event {
                case let .startAction(content):
                    actions.append(content)
                case let .endAction(content):
                    finishedActions.insert(content)
                case let .answerToken(token):
                    message.append(token)
                case let .finishAnswer(answer, links):
                    message = """
                    \(answer)

                    \(links.map { "- [\($0.title)](\($0.link))" }.joined(separator: "\n"))
                    """
                }

                await chatGPTService.memory.mutateHistory { history in
                    if history.last?.id == id {
                        history.removeLast()
                    }

                    let actionString = actions.map {
                        "> \(finishedActions.contains($0) ? "✅" : "🔍") \($0)"
                    }.joined(separator: "\n>\n")

                    if message.isEmpty {
                        reply.content = actionString
                    } else {
                        reply.content = """
                        \(actionString)

                        \(message)
                        """
                    }
                    history.append(reply)
                }
            }

        } catch {
            await chatGPTService.memory.mutateHistory { history in
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

