import ChatPlugins
import Foundation
import OpenAIService

public final class ChatService: ObservableObject {
    let chatGPTService: ChatGPTServiceType
    let plugins = registerPlugins(
        TerminalChatPlugin.self
    )
    var runningPlugin: ChatPlugin?

    public init(chatGPTService: ChatGPTServiceType) {
        self.chatGPTService = chatGPTService
    }
    
    public func send(content: String) async throws {
        // look for the prefix of content, see if there is something like /command.
        // If there is, then we need to find the plugin that can handle this command.
        // If there is no such plugin, then we just send the message to the GPT service.
        let regex = try NSRegularExpression(pattern: #"^\/([a-zA-Z0-9]+)"#)
        let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        if let match = matches.first {
            let command = String(content[Range(match.range(at: 1), in: content)!])
            if let pluginType = plugins[command] {
                let plugin = pluginType.init(inside: chatGPTService, delegate: self)
                await plugin.send(content: String(content.dropFirst(command.count + 1)))
            }
        } else {
            _ = try await chatGPTService.send(content: content, summary: nil)
        }
    }

    public func stopReceivingMessage() async {
        if let runningPlugin {
            await runningPlugin.cancel()
        }
        await chatGPTService.stopReceivingMessage()
    }

    public func clearHistory() async {
        if let runningPlugin {
            await runningPlugin.cancel()
        }
        await chatGPTService.clearHistory()
    }
}

extension ChatService: ChatPluginDelegate {
    public func pluginDidStartResponding(_ plugin: ChatPlugins.ChatPlugin) {
        Task {
            await chatGPTService.markReceivingMessage(true)
        }
    }
    
    public func pluginDidEndResponding(_ plugin: ChatPlugins.ChatPlugin) {
        Task {
            await chatGPTService.markReceivingMessage(false)
        }
    }
    
    public func pluginDidStart(_ plugin: ChatPlugin) {
        runningPlugin = plugin
    }
    
    public func pluginDidEnd(_ plugin: ChatPlugin) {
        runningPlugin = nil
    }
}

func registerPlugins(_ plugins: ChatPlugin.Type...) -> [String: ChatPlugin.Type] {
    var all = [String: ChatPlugin.Type]()
    for plugin in plugins {
        all[plugin.command] = plugin
    }
    return all
}
