import Foundation
import Preferences

public protocol ChatGPTConfiguration {
    var featureProvider: ChatFeatureProvider { get }
    var temperature: Double { get }
    var model: String { get }
    var endpoint: String { get }
    var apiKey: String { get }
    var stop: [String] { get }
    var maxToken: Int { get }
}

extension ChatGPTConfiguration {
    func endpoint(for provider: ChatFeatureProvider) -> String {
        switch provider {
        case .openAI:
            let baseURL = UserDefaults.shared.value(for: \.openAIBaseURL)
            if baseURL.isEmpty { return "https://api.openai.com/v1/chat/completions" }
            return "\(baseURL)/v1/chat/completions"
        case .azureOpenAI:
            let baseURL = UserDefaults.shared.value(for: \.azureOpenAIBaseURL)
            let deployment = UserDefaults.shared.value(for: \.azureChatGPTDeployment)
            let version = "2023-05-15"
            if baseURL.isEmpty { return "" }
            return "\(baseURL)/openai/deployments/\(deployment)/chat/completions?api-version=\(version)"
        }
    }

    func apiKey(for provider: ChatFeatureProvider) -> String {
        switch provider {
        case .openAI:
            return UserDefaults.shared.value(for: \.openAIAPIKey)
        case .azureOpenAI:
            return UserDefaults.shared.value(for: \.azureOpenAIAPIKey)
        }
    }
}

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

    public var maxToken: Int {
        UserDefaults.shared.value(for: \.chatGPTMaxToken)
    }

    public var stop: [String] {
        [""]
    }

    public init() {}
}

public class OverridingUserPreferenceChatGPTConfiguration: ChatGPTConfiguration {
    public struct Overriding {
        var featureProvider: ChatFeatureProvider?
        var temperature: Double?
        var model: String?
        var endPoint: String?
        var apiKey: String?
        var stop: [String]?
        var maxToken: Int?

        public init(
            temperature: Double? = nil,
            model: String? = nil,
            stop: [String]? = nil,
            maxToken: Int? = nil,
            featureProvider: ChatFeatureProvider? = nil,
            endPoint: String? = nil,
            apiKey: String? = nil
        ) {
            self.temperature = temperature
            self.model = model
            self.stop = stop
            self.maxToken = maxToken
            self.featureProvider = featureProvider
            self.endPoint = endPoint
            self.apiKey = apiKey
        }
    }

    private let userPreference = UserPreferenceChatGPTConfiguration()
    public var overriding = Overriding()

    public init(overriding: Overriding = .init()) {
        self.overriding = overriding
    }

    public var featureProvider: ChatFeatureProvider {
        overriding.featureProvider ?? userPreference.featureProvider
    }

    public var temperature: Double {
        overriding.temperature ?? userPreference.temperature
    }

    public var model: String {
        overriding.model ?? userPreference.model
    }

    public var endpoint: String {
        overriding.endPoint
            ?? overriding.featureProvider.map(endpoint(for:))
            ?? userPreference.endpoint
    }

    public var apiKey: String {
        overriding.apiKey
            ?? overriding.featureProvider.map(apiKey(for:))
            ?? userPreference.apiKey
    }

    public var stop: [String] {
        overriding.stop ?? userPreference.stop
    }

    public var maxToken: Int {
        overriding.maxToken ?? userPreference.maxToken
    }
}

