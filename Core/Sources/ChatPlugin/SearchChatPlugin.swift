import Environment
import Foundation
import OpenAIService
import PythonKit

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
        
    }

    public func cancel() async {
        isCancelled = true
    }

    public func stopResponding() async {
        isCancelled = true
    }
}

