import Foundation
import Preferences

public struct UserPreferenceChatGPTConfiguration: ChatGPTConfiguration {
    public var featureProvider: ChatFeatureProvider {
        UserDefaults.shared.value(for: \.chatFeatureProvider)
    }

    public var temperature: Double {
        min(max(0, UserDefaults.shared.value(for: \.chatGPTTemperature)), 2)
    }

    public var model: String {
        let value = UserDefaults.shared.value(for: \.chatGPTModel)
        if value.isEmpty { return "gpt-3.5-turbo" }
        return value
    }

    public var endpoint: String {
        endpoint(for: featureProvider)
    }

    public var apiKey: String {
        apiKey(for: featureProvider)
    }

    public var maxTokens: Int {
        UserDefaults.shared.value(for: \.chatGPTMaxToken)
    }

    public var stop: [String] {
        []
    }

    public var minimumReplyTokens: Int {
        300
    }

    public init() {}
}

public class OverridingChatGPTConfiguration<
    Configuration: ChatGPTConfiguration
>: ChatGPTConfiguration {
    public struct Overriding {
        var featureProvider: ChatFeatureProvider?
        var temperature: Double?
        var model: String?
        var endPoint: String?
        var apiKey: String?
        var stop: [String]?
        var maxTokens: Int?
        var minimumReplyTokens: Int?

        public init(
            temperature: Double? = nil,
            model: String? = nil,
            stop: [String]? = nil,
            maxTokens: Int? = nil,
            minimumReplyTokens: Int? = nil,
            featureProvider: ChatFeatureProvider? = nil,
            endPoint: String? = nil,
            apiKey: String? = nil
        ) {
            self.temperature = temperature
            self.model = model
            self.stop = stop
            self.maxTokens = maxTokens
            self.minimumReplyTokens = minimumReplyTokens
            self.featureProvider = featureProvider
            self.endPoint = endPoint
            self.apiKey = apiKey
        }
    }

    private let configuration: Configuration
    public var overriding = Overriding()

    public init(overriding configuration: Configuration, with overrides: Overriding = .init()) {
        self.overriding = overrides
        self.configuration = configuration
    }

    public var featureProvider: ChatFeatureProvider {
        overriding.featureProvider ?? configuration.featureProvider
    }

    public var temperature: Double {
        overriding.temperature ?? configuration.temperature
    }

    public var model: String {
        overriding.model ?? configuration.model
    }

    public var endpoint: String {
        overriding.endPoint
            ?? overriding.featureProvider.map(endpoint(for:))
            ?? configuration.endpoint
    }

    public var apiKey: String {
        overriding.apiKey
            ?? overriding.featureProvider.map(apiKey(for:))
            ?? configuration.apiKey
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
}

