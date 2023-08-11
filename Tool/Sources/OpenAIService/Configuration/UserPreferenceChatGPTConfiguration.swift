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

    public var runFunctionsAutomatically: Bool {
        true
    }

    public init() {}
}

public class OverridingChatGPTConfiguration: ChatGPTConfiguration {
    public struct Overriding {
        public var featureProvider: ChatFeatureProvider?
        public var temperature: Double?
        public var model: String?
        public var endPoint: String?
        public var apiKey: String?
        public var stop: [String]?
        public var maxTokens: Int?
        public var minimumReplyTokens: Int?
        public var runFunctionsAutomatically: Bool?

        public init(
            temperature: Double? = nil,
            model: String? = nil,
            stop: [String]? = nil,
            maxTokens: Int? = nil,
            minimumReplyTokens: Int? = nil,
            featureProvider: ChatFeatureProvider? = nil,
            endPoint: String? = nil,
            apiKey: String? = nil,
            runFunctionsAutomatically: Bool? = nil
        ) {
            self.temperature = temperature
            self.model = model
            self.stop = stop
            self.maxTokens = maxTokens
            self.minimumReplyTokens = minimumReplyTokens
            self.featureProvider = featureProvider
            self.endPoint = endPoint
            self.apiKey = apiKey
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

    public var runFunctionsAutomatically: Bool {
        overriding.runFunctionsAutomatically ?? configuration.runFunctionsAutomatically
    }
}

