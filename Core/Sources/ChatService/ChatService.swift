import ChatPlugins
import Combine
import Foundation
import OpenAIService

public final class ChatService: ObservableObject {
    public let chatGPTService: any ChatGPTServiceType
    let plugins = registerPlugins(
        TerminalChatPlugin.self,
        AITerminalChatPlugin.self
    )
    var runningPlugin: ChatPlugin?
    var cancellable = Set<AnyCancellable>()

    public init<T: ChatGPTServiceType>(chatGPTService: T) {
        self.chatGPTService = chatGPTService

        chatGPTService.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellable)
    }

    public func send(content: String) async throws {
        // look for the prefix of content, see if there is something like /command.
        // If there is, then we need to find the plugin that can handle this command.
        // If there is no such plugin, then we just send the message to the GPT service.
        let regex = try NSRegularExpression(pattern: #"^\/([a-zA-Z0-9]+)"#)
        let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        if let match = matches.first {
            let command = String(content[Range(match.range(at: 1), in: content)!])
            if command == "exit" {
                if let plugin = runningPlugin {
                    runningPlugin = nil
                    _ = await chatGPTService.mutateHistory { history in
                        history.append(.init(
                            role: .user,
                            content: "",
                            summary: "Exit plugin \(plugin.name)."
                        ))
                        history.append(.init(
                            role: .system,
                            content: "",
                            summary: "Exited plugin \(plugin.name)."
                        ))
                    }
                } else {
                    _ = await chatGPTService.mutateHistory { history in
                        history.append(.init(
                            role: .system,
                            content: "",
                            summary: "No plugin running."
                        ))
                    }
                }
            } else if let runningPlugin {
                await runningPlugin.send(content: content)
            } else if let pluginType = plugins[command] {
                let plugin = pluginType.init(inside: chatGPTService, delegate: self)
                if #available(macOS 13.0, *) {
                    await plugin.send(
                        content: String(
                            content.dropFirst(command.count + 1)
                                .trimmingPrefix(while: { $0 == " " })
                        )
                    )
                } else {
                    await plugin.send(content: String(content.dropFirst(command.count + 1)))
                }
            } else {
                _ = try await chatGPTService.send(content: content, summary: nil)
            }
        } else if let runningPlugin {
            await runningPlugin.send(content: content)
        } else {
            _ = try await chatGPTService.send(content: content, summary: nil)
        }
    }

    public func stopReceivingMessage() async {
        if let runningPlugin {
            await runningPlugin.stopResponding()
        }
        await chatGPTService.stopReceivingMessage()
    }

    public func clearHistory() async {
        if let runningPlugin {
            await runningPlugin.cancel()
        }
        await chatGPTService.clearHistory()
    }
    
    public func deleteMessage(id: String) async {
        await chatGPTService.mutateHistory { messages in
            messages.removeAll(where: { $0.id == id })
        }
    }
    
    public func resendMessage(id: String) async throws {
        if let message = (await chatGPTService.history).first(where: { $0.id == id }) {
            try await send(content: message.content)
        }
    }

    public func mutateSystemPrompt(_ newPrompt: String) async {
        await chatGPTService.mutateSystemPrompt(newPrompt)
    }
}

extension ChatService: ChatPluginDelegate {
    public func pluginDidStartResponding(_: ChatPlugins.ChatPlugin) {
        Task {
            await chatGPTService.markReceivingMessage(true)
        }
    }

    public func pluginDidEndResponding(_: ChatPlugins.ChatPlugin) {
        Task {
            await chatGPTService.markReceivingMessage(false)
        }
    }

    public func pluginDidStart(_ plugin: ChatPlugin) {
        runningPlugin = plugin
    }

    public func pluginDidEnd(_ plugin: ChatPlugin) {
        if runningPlugin === plugin {
            runningPlugin = nil
        }
    }

    public func shouldStartAnotherPlugin(_ type: ChatPlugin.Type, withContent content: String) {
        let plugin = type.init(inside: chatGPTService, delegate: self)
        Task {
            await plugin.send(content: content)
        }
    }
}

func registerPlugins(_ plugins: ChatPlugin.Type...) -> [String: ChatPlugin.Type] {
    var all = [String: ChatPlugin.Type]()
    for plugin in plugins {
        all[plugin.command] = plugin
    }
    return all
}
