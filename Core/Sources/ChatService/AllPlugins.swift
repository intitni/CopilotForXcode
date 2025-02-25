import ChatBasic
import Foundation
import OpenAIService
import ShortcutChatPlugin
import TerminalChatPlugin

let allPlugins: [LegacyChatPlugin.Type] = [
    LegacyChatPluginWrapper<TerminalChatPlugin>.self,
    LegacyChatPluginWrapper<ShortcutChatPlugin>.self,
]

protocol LegacyChatPlugin: AnyObject {
    static var command: String { get }
    var name: String { get }

    init(inside chatGPTService: any LegacyChatGPTServiceType, delegate: LegacyChatPluginDelegate)
    func send(content: String, originalMessage: String) async
    func cancel() async
    func stopResponding() async
}

protocol LegacyChatPluginDelegate: AnyObject {
    func pluginDidStart(_ plugin: LegacyChatPlugin)
    func pluginDidEnd(_ plugin: LegacyChatPlugin)
    func pluginDidStartResponding(_ plugin: LegacyChatPlugin)
    func pluginDidEndResponding(_ plugin: LegacyChatPlugin)
    func shouldStartAnotherPlugin(_ type: LegacyChatPlugin.Type, withContent: String)
}

final class LegacyChatPluginWrapper<Plugin: ChatPlugin>: LegacyChatPlugin {
    static var command: String { Plugin.command }
    var name: String { Plugin.name }

    let chatGPTService: any LegacyChatGPTServiceType
    weak var delegate: LegacyChatPluginDelegate?
    var isCancelled = false

    required init(
        inside chatGPTService: any LegacyChatGPTServiceType,
        delegate: any LegacyChatPluginDelegate
    ) {
        self.chatGPTService = chatGPTService
        self.delegate = delegate
    }

    func send(content: String, originalMessage: String) async {
        delegate?.pluginDidStart(self)
        delegate?.pluginDidStartResponding(self)

        let id = "\(Self.command)-\(UUID().uuidString)"
        var reply = ChatMessage(id: id, role: .assistant, content: "")

        await chatGPTService.memory.mutateHistory { history in
            history.append(.init(role: .user, content: originalMessage))
        }

        let plugin = Plugin()

        let stream = await plugin.send(.init(
            text: content,
            arguments: [],
            history: chatGPTService.memory.history
        ))

        do {
            var actions = [(id: String, name: String)]()
            var actionResults = [String: String]()
            var message = ""

            for try await response in stream {
                guard !isCancelled else { break }
                if Task.isCancelled { break }

                switch response {
                case .status:
                    break
                case let .content(content):
                    switch content {
                    case let .text(token):
                        message.append(token)
                    }
                case .attachments:
                    break
                case let .startAction(id, task):
                    actions.append((id: id, name: task))
                case let .finishAction(id, result):
                    actionResults[id] = switch result {
                    case let .failure(error):
                        error
                    case let .success(result):
                        result
                    }
                case .references:
                    break
                case .startNewMessage:
                    break
                case .reasoning:
                    break
                }

                await chatGPTService.memory.mutateHistory { history in
                    if history.last?.id == id {
                        history.removeLast()
                    }

                    let actionString = actions.map {
                        "> \($0.name): \(actionResults[$0.id] ?? "...")"
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

    func cancel() async {
        isCancelled = true
    }

    func stopResponding() async {
        isCancelled = true
    }
}

