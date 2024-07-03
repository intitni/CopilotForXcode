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

public class OverridingChatGPTConfiguration: ChatGPTConfiguration {
    public struct Overriding: Codable {
        public var temperature: Double?
        public var modelId: String?
        public var model: ChatModel?
        public var stop: [String]?
        public var maxTokens: Int?
        public var minimumReplyTokens: Int?
        public var runFunctionsAutomatically: Bool?
        public var apiKey: String?

        public init(
            temperature: Double? = nil,
            modelId: String? = nil,
            model: ChatModel? = nil,
            stop: [String]? = nil,
            maxTokens: Int? = nil,
            minimumReplyTokens: Int? = nil,
            runFunctionsAutomatically: Bool? = nil,
            apiKey: String? = nil
        ) {
            self.temperature = temperature
            self.modelId = modelId
            self.model = model
            self.stop = stop
            self.maxTokens = maxTokens
            self.minimumReplyTokens = minimumReplyTokens
            self.runFunctionsAutomatically = runFunctionsAutomatically
            self.apiKey = apiKey
        }
    }

    private let configuration: ChatGPTConfiguration
    public var overriding = Overriding()
    public var textWindowTerminator: ((String) -> Bool)?

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
        guard let id = overriding.modelId else { return configuration.model }
        if id == "com.github.copilot" {
            return .init(id: id, name: "GitHub Copilot", format: .openAI, info: .init())
        }
        guard let model = models.first(where: { $0.id == id }) else { return configuration.model }
        return model
    }

    public var stop: [String] {
        overriding.stop ?? configuration.stop
    }

    public var maxTokens: Int {
        if let maxTokens = overriding.maxTokens { return maxTokens }
        if let model { return model.info.maxTokens }
        return configuration.maxTokens
    }

    public var minimumReplyTokens: Int {
        if let minimumReplyTokens = overriding.minimumReplyTokens { return minimumReplyTokens }
        return maxTokens / 5
    }

    public var runFunctionsAutomatically: Bool {
        overriding.runFunctionsAutomatically ?? configuration.runFunctionsAutomatically
    }

    public var apiKey: String {
        if let apiKey = overriding.apiKey { return apiKey }
        guard let name = model?.info.apiKeyName else { return configuration.apiKey }
        return (try? Keychain.apiKey.get(name)) ?? configuration.apiKey
    }

    public var shouldEndTextWindow: (String) -> Bool {
        textWindowTerminator ?? configuration.shouldEndTextWindow
    }
}
