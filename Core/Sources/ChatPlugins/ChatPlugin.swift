import Foundation
import OpenAIService

public protocol ChatPlugin {
    static var command: String { get }
    var name: String { get }

    init(inside chatGPTService: ChatGPTServiceType, delegate: ChatPluginDelegate)
    func send(content: String) async
    func cancel() async
}

public protocol ChatPluginDelegate: AnyObject {
    func pluginDidStart(_ plugin: ChatPlugin)
    func pluginDidEnd(_ plugin: ChatPlugin)
}
