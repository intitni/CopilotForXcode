import Foundation
import OpenAIService

public protocol ChatPlugin: AnyObject {
    /// Should be [a-zA-Z0-9]+
    static var command: String { get }
    var name: String { get }

    init(inside chatGPTService: any LegacyChatGPTServiceType, delegate: ChatPluginDelegate)
    func send(content: String, originalMessage: String) async
    func cancel() async
    func stopResponding() async
}

public protocol ChatPluginDelegate: AnyObject {
    func pluginDidStart(_ plugin: ChatPlugin)
    func pluginDidEnd(_ plugin: ChatPlugin)
    func pluginDidStartResponding(_ plugin: ChatPlugin)
    func pluginDidEndResponding(_ plugin: ChatPlugin)
    func shouldStartAnotherPlugin(_ type: ChatPlugin.Type, withContent: String)
}
