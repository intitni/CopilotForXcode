import Foundation
import Keychain
import XCTest

@testable import ServiceUpdateMigration

final class MigrateTo240Tests: XCTestCase {
    let userDefaults = UserDefaults(suiteName: "MigrateTo240Tests")!
    
    override func tearDown() async throws {
        userDefaults.removePersistentDomain(forName: "MigrateTo240Tests")
    }
    
    func test_migrateTo240_no_data_to_migrate() async throws {
        let keychain = FakeKeyChain()

        try migrateTo240(defaults: userDefaults, keychain: keychain)

        XCTAssertTrue(try keychain.getAll().isEmpty, "No api key to migrate")

        let chatModels = userDefaults.value(for: \.chatModels)
        let embeddingModels = userDefaults.value(for: \.embeddingModels)

        for chatModel in chatModels {
            switch chatModel.format {
            case .openAI:
                XCTAssertEqual(chatModel.name, "OpenAI")
                XCTAssertEqual(chatModel.info, .init(
                    apiKeyName: "OpenAI",
                    baseURL: "",
                    maxTokens: 16385,
                    supportsFunctionCalling: true,
                    modelName: "gpt-3.5-turbo"
                ))
            case .azureOpenAI:
                XCTAssertEqual(chatModel.name, "Azure OpenAI")
                XCTAssertEqual(chatModel.info, .init(
                    apiKeyName: "Azure OpenAI",
                    baseURL: "",
                    maxTokens: 4000,
                    supportsFunctionCalling: true,
                    modelName: ""
                ))
            default:
                XCTFail()
            }
        }

        for embeddingModel in embeddingModels {
            switch embeddingModel.format {
            case .openAI:
                XCTAssertEqual(embeddingModel.name, "OpenAI")
                XCTAssertEqual(embeddingModel.info, .init(
                    apiKeyName: "OpenAI",
                    baseURL: "",
                    maxTokens: 8191,
                    modelName: "text-embedding-ada-002"
                ))
            case .azureOpenAI:
                XCTAssertEqual(embeddingModel.name, "Azure OpenAI")
                XCTAssertEqual(embeddingModel.info, .init(
                    apiKeyName: "Azure OpenAI",
                    baseURL: "",
                    maxTokens: 8191,
                    modelName: ""
                ))
            default:
                XCTFail()
            }
        }
    }

    func test_migrateTo240_migrate_data_use_openAI() async throws {
        let keychain = FakeKeyChain()

        userDefaults.set("Key1", forKey: "OpenAIAPIKey")
        userDefaults.set("openai.com", forKey: "OpenAIBaseURL")
        userDefaults.set("gpt-500", forKey: "ChatGPTModel")
        userDefaults.set(200, forKey: "ChatGPTMaxToken")
        userDefaults.set("embedding-200", forKey: "OpenAIEmbeddingModel")
        userDefaults.set("Key2", forKey: "AzureOpenAIAPIKey")
        userDefaults.set("azure.com", forKey: "AzureOpenAIBaseURL")
        userDefaults.set("gpt-800", forKey: "AzureChatGPTDeployment")
        userDefaults.set("embedding-800", forKey: "AzureEmbeddingDeployment")
        userDefaults.set("openAI", forKey: "ChatFeatureProvider")
        userDefaults.set("openAI", forKey: "EmbeddingFeatureProvider")

        try migrateTo240(defaults: userDefaults, keychain: keychain)

        XCTAssertEqual(try keychain.getAll(), [
            "OpenAI": "Key1",
            "Azure OpenAI": "Key2",
        ])

        let chatModels = userDefaults.value(for: \.chatModels)
        let embeddingModels = userDefaults.value(for: \.embeddingModels)

        XCTAssertEqual(chatModels.count, 2)
        XCTAssertEqual(embeddingModels.count, 2)

        XCTAssertEqual(
            userDefaults.value(for: \.defaultChatFeatureChatModelId),
            chatModels.first(where: { $0.format == .openAI })?.id
        )
        XCTAssertEqual(
            userDefaults.value(for: \.defaultChatFeatureEmbeddingModelId),
            embeddingModels.first(where: { $0.format == .openAI })?.id
        )

        for chatModel in chatModels {
            switch chatModel.format {
            case .openAI:
                XCTAssertEqual(chatModel.name, "OpenAI")
                XCTAssertEqual(chatModel.info, .init(
                    apiKeyName: "OpenAI",
                    baseURL: "openai.com",
                    maxTokens: 200,
                    supportsFunctionCalling: true,
                    modelName: "gpt-500"
                ))
            case .azureOpenAI:
                XCTAssertEqual(chatModel.name, "Azure OpenAI")
                XCTAssertEqual(chatModel.info, .init(
                    apiKeyName: "Azure OpenAI",
                    baseURL: "azure.com",
                    maxTokens: 200,
                    supportsFunctionCalling: true,
                    modelName: "gpt-800"
                ))
            default:
                XCTFail()
            }
        }

        for embeddingModel in embeddingModels {
            switch embeddingModel.format {
            case .openAI:
                XCTAssertEqual(embeddingModel.name, "OpenAI")
                XCTAssertEqual(embeddingModel.info, .init(
                    apiKeyName: "OpenAI",
                    baseURL: "openai.com",
                    maxTokens: 8191,
                    modelName: "embedding-200"
                ))
            case .azureOpenAI:
                XCTAssertEqual(embeddingModel.name, "Azure OpenAI")
                XCTAssertEqual(embeddingModel.info, .init(
                    apiKeyName: "Azure OpenAI",
                    baseURL: "azure.com",
                    maxTokens: 8191,
                    modelName: "embedding-800"
                ))
            default:
                XCTFail()
            }
        }
    }

    func test_migrateTo240_migrate_data_use_azureOpenAI() async throws {
        let keychain = FakeKeyChain()

        userDefaults.set("Key1", forKey: "OpenAIAPIKey")
        userDefaults.set("openai.com", forKey: "OpenAIBaseURL")
        userDefaults.set("gpt-500", forKey: "ChatGPTModel")
        userDefaults.set(200, forKey: "ChatGPTMaxToken")
        userDefaults.set("embedding-200", forKey: "OpenAIEmbeddingModel")
        userDefaults.set("Key2", forKey: "AzureOpenAIAPIKey")
        userDefaults.set("azure.com", forKey: "AzureOpenAIBaseURL")
        userDefaults.set("gpt-800", forKey: "AzureChatGPTDeployment")
        userDefaults.set("embedding-800", forKey: "AzureEmbeddingDeployment")
        userDefaults.set("azureOpenAI", forKey: "ChatFeatureProvider")
        userDefaults.set("azureOpenAI", forKey: "EmbeddingFeatureProvider")

        try migrateTo240(defaults: userDefaults, keychain: keychain)

        let chatModels = userDefaults.value(for: \.chatModels)
        let embeddingModels = userDefaults.value(for: \.embeddingModels)

        XCTAssertEqual(chatModels.count, 2)
        XCTAssertEqual(embeddingModels.count, 2)

        XCTAssertEqual(
            userDefaults.value(for: \.defaultChatFeatureChatModelId),
            chatModels.first(where: { $0.format == .azureOpenAI })?.id
        )
        XCTAssertEqual(
            userDefaults.value(for: \.defaultChatFeatureEmbeddingModelId),
            embeddingModels.first(where: { $0.format == .azureOpenAI })?.id
        )
    }
}

