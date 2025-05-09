import AIModel
import AsyncAlgorithms
import ChatBasic
import Foundation
import GitHubCopilotService
import Logger
import Preferences

public enum AvailableGitHubCopilotModel: String, CaseIterable {
    case claude35sonnet = "claude-3.5-sonnet"
    case o1Mini = "o1-mini"
    case o1 = "o1"
    case gpt4Turbo = "gpt-4-turbo"
    case gpt4oMini = "gpt-4o-mini"
    case gpt4o = "gpt-4o"
    case gpt4 = "gpt-4"
    case gpt35Turbo = "gpt-3.5-turbo"
    
    public var contextWindow: Int {
        switch self {
        case .claude35sonnet:
            return 200_000
        case .o1Mini:
            return 128_000
        case .o1:
            return 128_000
        case .gpt4Turbo:
            return 128_000
        case .gpt4oMini:
            return 128_000
        case .gpt4o:
            return 128_000
        case .gpt4:
            return 32_768
        case .gpt35Turbo:
            return 16_384
        }
    }
}

/// Looks like it's used in many other popular repositories so maybe it's safe.
actor GitHubCopilotChatCompletionsService: ChatCompletionsStreamAPI, ChatCompletionsAPI {
    
    let chatModel: ChatModel
    let requestBody: ChatCompletionsRequestBody

    init(
        model: ChatModel,
        requestBody: ChatCompletionsRequestBody
    ) {
        var model = model
        model.format = .openAICompatible
        chatModel = model
        self.requestBody = requestBody
    }

    func callAsFunction() async throws
        -> AsyncThrowingStream<ChatCompletionsStreamDataChunk, any Error>
    {
        let service = try await buildService()
        return try await service()
    }

    func callAsFunction() async throws -> ChatCompletionResponseBody {
        let service = try await buildService()
        return try await service()
    }

    private func buildService() async throws -> OpenAIChatCompletionsService {
        let token = try await GitHubCopilotExtension.fetchToken()

        guard let endpoint = URL(string: token.endpoints.api + "/chat/completions") else {
            throw ChatGPTServiceError.endpointIncorrect
        }

        return OpenAIChatCompletionsService(
            apiKey: token.token,
            model: chatModel,
            endpoint: endpoint,
            requestBody: requestBody
        ) { request in

//            POST /chat/completions HTTP/2
//            :authority: api.individual.githubcopilot.com
//            authorization: Bearer *
//            x-request-id: *
//            openai-organization: github-copilot
//            vscode-sessionid: *
//            vscode-machineid: *
//            editor-version: vscode/1.89.1
//            editor-plugin-version: Copilot for Xcode/0.35.5
//            copilot-language-server-version: 1.236.0
//            x-github-api-version: 2023-07-07
//            openai-intent: conversation-panel
//            content-type: application/json
//            user-agent: GithubCopilot/1.236.0
//            content-length: 9061
//            accept: */*
//            accept-encoding: gzip,deflate,br

            request.setValue(
                "Copilot for Xcode/\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")",
                forHTTPHeaderField: "Editor-Version"
            )
            request.setValue("Bearer \(token.token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("vscode-chat", forHTTPHeaderField: "Copilot-Integration-Id")
            request.setValue("2023-07-07", forHTTPHeaderField: "X-Github-Api-Version")
        }
    }
}

