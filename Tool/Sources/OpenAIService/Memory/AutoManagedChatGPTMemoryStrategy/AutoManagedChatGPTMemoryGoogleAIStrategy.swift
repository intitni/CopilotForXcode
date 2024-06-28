import ChatBasic
import Foundation
import GoogleGenerativeAI
import Logger

extension AutoManagedChatGPTMemory {
    struct GoogleAIStrategy: AutoManagedChatGPTMemoryStrategy {
        let configuration: ChatGPTConfiguration

        func countToken(_ message: ChatMessage) async -> Int {
            (await OpenAIStrategy().countToken(message)) + 20
            // Using local tiktoken instead until I find a faster solution.
            // The official solution requires sending a lot of requests when adjusting the prompt.
            // adding 20 just incase.

//            guard let model = configuration.model else {
//                return 0
//            }
//            let aiModel = GenerativeModel(name: model.info.modelName, apiKey:
//            configuration.apiKey)
//            if message.isEmpty { return 0 }
//            let modelMessage = ModelContent(message)
//            return (try? await aiModel.countTokens([modelMessage]).totalTokens) ?? 0
        }

        func countToken<F>(_: F) async -> Int where F: ChatGPTFunction {
            // function is not supported.
            return 0
        }
    }
}

