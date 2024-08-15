import AIModel
import ChatBasic
import Dependencies
import Foundation

protocol ChatCompletionsAPIBuilder {
    func buildStreamAPI(
        model: ChatModel,
        endpoint: URL,
        apiKey: String,
        requestBody: ChatCompletionsRequestBody,
        prompt: ChatGPTPrompt
    ) -> any ChatCompletionsStreamAPI

    func buildNonStreamAPI(
        model: ChatModel,
        endpoint: URL,
        apiKey: String,
        requestBody: ChatCompletionsRequestBody,
        prompt: ChatGPTPrompt
    ) -> any ChatCompletionsAPI
}

struct DefaultChatCompletionsAPIBuilder: ChatCompletionsAPIBuilder {
    func buildStreamAPI(
        model: ChatModel,
        endpoint: URL,
        apiKey: String,
        requestBody: ChatCompletionsRequestBody,
        prompt: ChatGPTPrompt
    ) -> any ChatCompletionsStreamAPI {
        if model.id == "com.github.copilot" {
            return BuiltinExtensionChatCompletionsService(
                extensionIdentifier: model.id,
                requestBody: requestBody
            )
        }

        switch model.format {
        case .googleAI:
            return GoogleAIChatCompletionsService(
                apiKey: apiKey,
                model: model,
                requestBody: requestBody,
                prompt: prompt,
                baseURL: endpoint.absoluteString
            )
        case .openAI, .openAICompatible, .azureOpenAI:
            return OpenAIChatCompletionsService(
                apiKey: apiKey,
                model: model,
                endpoint: endpoint,
                requestBody: requestBody
            )
        case .ollama:
            return OllamaChatCompletionsService(
                apiKey: apiKey,
                model: model,
                endpoint: endpoint,
                requestBody: requestBody
            )
        case .claude:
            return ClaudeChatCompletionsService(
                apiKey: apiKey,
                model: model,
                endpoint: endpoint,
                requestBody: requestBody
            )
        }
    }

    func buildNonStreamAPI(
        model: ChatModel,
        endpoint: URL,
        apiKey: String,
        requestBody: ChatCompletionsRequestBody,
        prompt: ChatGPTPrompt
    ) -> any ChatCompletionsAPI {
        if model.id == "com.github.copilot" {
            return BuiltinExtensionChatCompletionsService(
                extensionIdentifier: model.id,
                requestBody: requestBody
            )
        }

        switch model.format {
        case .googleAI:
            return GoogleAIChatCompletionsService(
                apiKey: apiKey,
                model: model,
                requestBody: requestBody,
                prompt: prompt,
                baseURL: endpoint.absoluteString
            )
        case .openAI, .openAICompatible, .azureOpenAI:
            return OpenAIChatCompletionsService(
                apiKey: apiKey,
                model: model,
                endpoint: endpoint,
                requestBody: requestBody
            )
        case .ollama:
            return OllamaChatCompletionsService(
                apiKey: apiKey,
                model: model,
                endpoint: endpoint,
                requestBody: requestBody
            )
        case .claude:
            return ClaudeChatCompletionsService(
                apiKey: apiKey,
                model: model,
                endpoint: endpoint,
                requestBody: requestBody
            )
        }
    }
}

struct ChatCompletionsAPIBuilderDependencyKey: DependencyKey {
    static var liveValue = DefaultChatCompletionsAPIBuilder()
}

extension DependencyValues {
    var chatCompletionsAPIBuilder: ChatCompletionsAPIBuilder {
        get { self[ChatCompletionsAPIBuilderDependencyKey.self] }
        set { self[ChatCompletionsAPIBuilderDependencyKey.self] = newValue }
    }
}
