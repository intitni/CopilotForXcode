import AIModel
import ChatBasic
import Foundation
import Keychain
import Preferences

public struct UserPreferenceChatGPTConfiguration: ChatGPTConfiguration {
    public var chatModelKey: KeyPath<UserDefaultPreferenceKeys, PreferenceKey<String>>?

    public var temperature: Double {
        min(max(0, UserDefaults.shared.value(for: \.chatGPTTemperature)), 2)
    }

    public var model: ChatModel? {
        let models = UserDefaults.shared.value(for: \.chatModels)

        if let chatModelKey {
            let id = UserDefaults.shared.value(for: chatModelKey)
            if let model = models.first(where: { $0.id == id }) {
                return model
            }
        }

        let id = UserDefaults.shared.value(for: \.defaultChatFeatureChatModelId)
        return models.first { $0.id == id }
            ?? models.first
    }

    public var maxTokens: Int {
        model?.info.maxTokens ?? 0
    }

    public var stop: [String] {
        []
    }

    public var minimumReplyTokens: Int {
        maxTokens / 5
    }

    public var runFunctionsAutomatically: Bool {
        true
    }

    public var shouldEndTextWindow: (String) -> Bool {
        { _ in true }
    }

    public init(chatModelKey: KeyPath<UserDefaultPreferenceKeys, PreferenceKey<String>>? = nil) {
        self.chatModelKey = chatModelKey
    }
}

