import AIModel
import Foundation
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
        300
    }

    public var runFunctionsAutomatically: Bool {
        true
    }

    public init(chatModelKey: KeyPath<UserDefaultPreferenceKeys, PreferenceKey<String>>? = nil) {
        self.chatModelKey = chatModelKey
    }
}

public class OverridingChatGPTConfiguration: ChatGPTConfiguration {
    public struct Overriding: Codable {
        public var temperature: Double?
        public var modelId: String?
        public var model: ChatModel?
        public var stop: [String]?
        public var maxTokens: Int?
        public var minimumReplyTokens: Int?
        public var runFunctionsAutomatically: Bool?

        public init(
            temperature: Double? = nil,
            modelId: String? = nil,
            model: ChatModel? = nil,
            stop: [String]? = nil,
            maxTokens: Int? = nil,
            minimumReplyTokens: Int? = nil,
            runFunctionsAutomatically: Bool? = nil
        ) {
            self.temperature = temperature
            self.modelId = modelId
            self.model = model
            self.stop = stop
            self.maxTokens = maxTokens
            self.minimumReplyTokens = minimumReplyTokens
            self.runFunctionsAutomatically = runFunctionsAutomatically
        }
    }

    private let configuration: ChatGPTConfiguration
    public var overriding = Overriding()

    public init(
        overriding configuration: any ChatGPTConfiguration,
        with overrides: Overriding = .init()
    ) {
        overriding = overrides
        self.configuration = configuration
    }

    public var temperature: Double {
        overriding.temperature ?? configuration.temperature
    }

    public var model: ChatModel? {
        if let model = overriding.model { return model }
        let models = UserDefaults.shared.value(for: \.chatModels)
        guard let id = overriding.modelId,
              let model = models.first(where: { $0.id == id })
        else { return configuration.model }
        return model
    }

    public var stop: [String] {
        overriding.stop ?? configuration.stop
    }

    public var maxTokens: Int {
        overriding.maxTokens ?? configuration.maxTokens
    }

    public var minimumReplyTokens: Int {
        overriding.minimumReplyTokens ?? configuration.minimumReplyTokens
    }

    public var runFunctionsAutomatically: Bool {
        overriding.runFunctionsAutomatically ?? configuration.runFunctionsAutomatically
    }
}

