import AIModel
import Foundation
import Keychain
import Preferences

func migrateTo240(
    defaults: UserDefaults = .shared,
    keychain: KeychainType = Keychain.apiKey
) throws {
    let finishedMigrationKey = "MigrateTo240Finished"
    if defaults.bool(forKey: finishedMigrationKey) { return }

    do {
        let chatModelOpenAIId = UUID().uuidString
        let chatModelAzureOpenAIId = UUID().uuidString
        let embeddingModelOpenAIId = UUID().uuidString
        let embeddingModelAzureOpenAIId = UUID().uuidString
        
        let openAIAPIKeyName = "OpenAI"
        let openAIAPIKey = defaults.deprecatedValue(for: \.openAIAPIKey)
        if !openAIAPIKey.isEmpty {
            try keychain.update(openAIAPIKey, key: openAIAPIKeyName)
        }
        
        let azureOpenAIAPIKeyName = "Azure OpenAI"
        let azureOpenAIAPIKey = defaults.deprecatedValue(for: \.azureOpenAIAPIKey)
        if !azureOpenAIAPIKey.isEmpty {
            try keychain.update(azureOpenAIAPIKey, key: azureOpenAIAPIKeyName)
        }
        
        defaults.set({
            let openAIModel = ChatGPTModel(rawValue: defaults.deprecatedValue(for: \.chatGPTModel))
            
            let openAI = ChatModel(
                id: chatModelOpenAIId,
                name: "OpenAI",
                format: .openAI,
                info: .init(
                    apiKeyName: openAIAPIKeyName,
                    baseURL: defaults.deprecatedValue(for: \.openAIBaseURL),
                    maxTokens: openAIModel?.maxToken ?? defaults
                        .deprecatedValue(for: \.chatGPTMaxToken),
                    modelName: openAIModel?.rawValue ?? defaults
                        .deprecatedValue(for: \.chatGPTModel)
                )
            )
            let azureOpenAI = ChatModel(
                id: chatModelAzureOpenAIId,
                name: "Azure OpenAI",
                format: .azureOpenAI,
                info: .init(
                    apiKeyName: azureOpenAIAPIKeyName,
                    baseURL: defaults.deprecatedValue(for: \.azureOpenAIBaseURL),
                    maxTokens: defaults.deprecatedValue(for: \.chatGPTMaxToken),
                    modelName: defaults
                        .deprecatedValue(for: \.azureChatGPTDeployment)
                )
            )
            
            return [openAI, azureOpenAI]
        }(), for: \.chatModels)
        
        defaults.set({
            if defaults.deprecatedValue(for: \.chatFeatureProvider) == .azureOpenAI {
                return chatModelAzureOpenAIId
            }
            return chatModelOpenAIId
        }(), for: \.defaultChatFeatureChatModelId)
        
        defaults.set({
            let openAIModel = OpenAIEmbeddingModel(
                rawValue: defaults.deprecatedValue(for: \.embeddingModel)
            )
            
            let openAI = EmbeddingModel(
                id: embeddingModelOpenAIId,
                name: "OpenAI",
                format: .openAI,
                info: .init(
                    apiKeyName: openAIAPIKeyName,
                    baseURL: defaults.deprecatedValue(for: \.openAIBaseURL),
                    maxTokens: openAIModel?.maxToken ?? 8191,
                    modelName: openAIModel?.rawValue ?? defaults.deprecatedValue(for: \.embeddingModel)
                )
            )
            
            let azureOpenAI = EmbeddingModel(
                id: embeddingModelAzureOpenAIId,
                name: "Azure OpenAI",
                format: .azureOpenAI,
                info: .init(
                    apiKeyName: azureOpenAIAPIKeyName,
                    baseURL: defaults.deprecatedValue(for: \.azureOpenAIBaseURL),
                    maxTokens: 8191,
                    modelName: defaults
                        .deprecatedValue(for: \.azureEmbeddingDeployment)
                )
            )
            
            return [openAI, azureOpenAI]
        }(), for: \.embeddingModels)
        
        defaults.set({
            if defaults.deprecatedValue(for: \.embeddingFeatureProvider) == .azureOpenAI {
                return embeddingModelAzureOpenAIId
            }
            return embeddingModelOpenAIId
        }(), for: \.defaultChatFeatureEmbeddingModelId)
        
        defaults.set(true, forKey: finishedMigrationKey)
    } catch {
        print(error.localizedDescription)
        throw error
    }
}

