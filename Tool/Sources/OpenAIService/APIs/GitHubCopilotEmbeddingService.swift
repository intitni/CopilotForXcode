import AIModel
import AsyncAlgorithms
import ChatBasic
import Foundation
import GitHubCopilotService
import Logger
import Preferences

/// Looks like it's used in many other popular repositories so maybe it's safe.
actor GitHubCopilotEmbeddingService: EmbeddingAPI {
    let chatModel: EmbeddingModel

    init(model: EmbeddingModel) {
        var model = model
        model.format = .openAICompatible
        chatModel = model
    }

    func embed(text: String) async throws -> EmbeddingResponse {
        let service = try await buildService()
        return try await service.embed(text: text)
    }

    func embed(texts: [String]) async throws -> EmbeddingResponse {
        let service = try await buildService()
        return try await service.embed(texts: texts)
    }

    func embed(tokens: [[Int]]) async throws -> EmbeddingResponse {
        let service = try await buildService()
        return try await service.embed(tokens: tokens)
    }

    private func buildService() async throws -> OpenAIEmbeddingService {
        let token = try await GitHubCopilotExtension.fetchToken()

        return OpenAIEmbeddingService(
            apiKey: token.token,
            model: chatModel,
            endpoint: token.endpoints.api + "/embeddings"
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

