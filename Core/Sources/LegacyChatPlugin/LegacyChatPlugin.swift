import Foundation
import OpenAIService

public protocol LegacyChatPlugin: AnyObject {
    /// Should be [a-zA-Z0-9]+
    static var command: String { get }
    var name: String { get }

    init(inside chatGPTService: any LegacyChatGPTServiceType, delegate: LegacyChatPluginDelegate)
    func send(content: String, originalMessage: String) async
    func cancel() async
    func stopResponding() async
}

public protocol LegacyChatPluginDelegate: AnyObject {
    func pluginDidStart(_ plugin: LegacyChatPlugin)
    func pluginDidEnd(_ plugin: LegacyChatPlugin)
    func pluginDidStartResponding(_ plugin: LegacyChatPlugin)
    func pluginDidEndResponding(_ plugin: LegacyChatPlugin)
    func shouldStartAnotherPlugin(_ type: LegacyChatPlugin.Type, withContent: String)
}
