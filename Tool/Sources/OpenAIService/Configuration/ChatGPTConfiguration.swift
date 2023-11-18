import Foundation
import AIModel
import Preferences
import Keychain

public protocol ChatGPTConfiguration {
    var model: ChatModel? { get }
    var temperature: Double { get }
    var apiKey: String { get }
    var stop: [String] { get }
    var maxTokens: Int { get }
    var minimumReplyTokens: Int { get }
    var runFunctionsAutomatically: Bool { get }
    var shouldEndTextWindow: (String) -> Bool { get }
}

public extension ChatGPTConfiguration {
    var endpoint: String {
        model?.endpoint ?? ""
    }
    
    var apiKey: String {
        guard let name = model?.info.apiKeyName else { return "" }
        return (try? Keychain.apiKey.get(name)) ?? ""
    }

    func overriding(
        _ overrides: OverridingChatGPTConfiguration.Overriding
    ) -> OverridingChatGPTConfiguration {
        .init(overriding: self, with: overrides)
    }

    func overriding(
        _ update: (inout OverridingChatGPTConfiguration.Overriding) -> Void = { _ in }
    ) -> OverridingChatGPTConfiguration {
        var overrides = OverridingChatGPTConfiguration.Overriding()
        update(&overrides)
        return .init(overriding: self, with: overrides)
    }
}

