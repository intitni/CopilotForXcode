import Foundation
import AIModel
import Preferences
import Keychain

public protocol ChatGPTConfiguration {
    var model: ChatModel { get }
    var temperature: Double { get }
    var apiKey: String { get }
    var stop: [String] { get }
    var maxTokens: Int { get }
    var minimumReplyTokens: Int { get }
    var runFunctionsAutomatically: Bool { get }
}

public extension ChatGPTConfiguration {
    var endpoint: String {
        model.endpoint
    }
    
    var apiKey: String {
        (try? Keychain.apiKey.get(model.info.apiKeyName)) ?? ""
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

