//import Foundation
//import Preferences
//import PythonHelper
//import PythonKit
//
//public enum LangChainChatModel {
//    /// Dynamically create a ChatOpenAI object based on the user's preferences.
//    public static func DynamicChatOpenAI(
//        temperature: Double
//    ) throws -> PythonObject {
//        switch UserDefaults.shared.value(for: \.chatFeatureProvider) {
//        case .openAI:
//            let model = UserDefaults.shared.value(for: \.chatGPTModel)
//            let apiBaseURL = UserDefaults.shared.value(for: \.openAIBaseURL)
//            let apiKey = UserDefaults.shared.value(for: \.openAIAPIKey)
//            let chatModels = try Python.attemptImportOnPythonThread("langchain.chat_models")
//            let ChatOpenAI = chatModels.ChatOpenAI
//            return ChatOpenAI(
//                temperature: temperature,
//                model: model,
//                openai_api_base: "\(apiBaseURL)/v1",
//                openai_api_key: apiKey
//            )
//        case .azureOpenAI:
//            let apiBaseURL = UserDefaults.shared.value(for: \.azureOpenAIBaseURL)
//            let apiKey = UserDefaults.shared.value(for: \.azureOpenAIAPIKey)
//            let deployment = UserDefaults.shared.value(for: \.azureChatGPTDeployment)
//            let chatModels = try Python.attemptImportOnPythonThread("langchain.chat_models")
//            let ChatOpenAI = chatModels.AzureChatOpenAI
//            return ChatOpenAI(
//                temperature: temperature,
//                openai_api_type: "azure",
//                openai_api_version: "2023-03-15-preview",
//                deployment_name: deployment,
//                openai_api_base: apiBaseURL,
//                openai_api_key: apiKey
//            )
//        }
//    }
//}

