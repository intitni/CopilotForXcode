import ChatPlugin
import Combine
import Foundation
import OpenAIService

final class ChatPluginController {
    let chatGPTService: any LegacyChatGPTServiceType
    let plugins: [String: ChatPlugin.Type]
    var runningPlugin: ChatPlugin?
    weak var chatService: ChatService?
    
    init(chatGPTService: any LegacyChatGPTServiceType, plugins: [ChatPlugin.Type]) {
        self.chatGPTService = chatGPTService
        var all = [String: ChatPlugin.Type]()
        for plugin in plugins {
            all[plugin.command.lowercased()] = plugin
        }
        self.plugins = all
    }

    convenience init(chatGPTService: any LegacyChatGPTServiceType, plugins: ChatPlugin.Type...) {
        self.init(chatGPTService: chatGPTService, plugins: plugins)
    }

    /// Handle the message in a plugin if required. Return false if no plugin handles the message.
    func handleContent(_ content: String) async throws -> Bool {
        // look for the prefix of content, see if there is something like /command.
        // If there is, then we need to find the plugin that can handle this command.
        // If there is no such plugin, then we just send the message to the GPT service.
        let regex = try NSRegularExpression(pattern: #"^\/([a-zA-Z0-9]+)"#)
        let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        if let match = matches.first {
            let command = String(content[Range(match.range(at: 1), in: content)!]).lowercased()
            // handle exit plugin
            if command == "exit" {
                if let plugin = runningPlugin {
                    runningPlugin = nil
                    _ = await chatGPTService.memory.mutateHistory { history in
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
                    _ = await chatGPTService.memory.mutateHistory { history in
                        history.append(.init(
                            role: .system,
                            content: "",
                            summary: "No plugin running."
                        ))
                    }
                }
                return true
            }

            // pass message to running plugin
            if let runningPlugin {
                await runningPlugin.send(content: content, originalMessage: content)
                return true
            }

            // pass message to new plugin
            if let pluginType = plugins[command] {
                let plugin = pluginType.init(inside: chatGPTService, delegate: self)
                if #available(macOS 13.0, *) {
                    await plugin.send(
                        content: String(
                            content.dropFirst(command.count + 1)
                                .trimmingPrefix(while: { $0 == " " })
                        ),
                        originalMessage: content
                    )
                } else {
                    await plugin.send(
                        content: String(content.dropFirst(command.count + 1)),
                        originalMessage: content
                    )
                }
                return true
            }

            return false
        } else if let runningPlugin {
            // pass message to running plugin
            await runningPlugin.send(content: content, originalMessage: content)
            return true
        } else {
            return false
        }
    }
    
    func stopResponding() async {
        await runningPlugin?.stopResponding()
    }
    
    func cancel() async {
        await runningPlugin?.cancel()
    }
}

// MARK: - ChatPluginDelegate

extension ChatPluginController: ChatPluginDelegate {
    public func pluginDidStartResponding(_: ChatPlugin) {
        chatService?.isReceivingMessage = true
    }

    public func pluginDidEndResponding(_: ChatPlugin) {
        chatService?.isReceivingMessage = false
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
            await plugin.send(content: content, originalMessage: content)
        }
    }
}

