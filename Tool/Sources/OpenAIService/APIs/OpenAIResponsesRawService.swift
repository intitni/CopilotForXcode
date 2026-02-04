import AIModel
import AsyncAlgorithms
import ChatBasic
import Foundation
import GitHubCopilotService
import JoinJSON
import Logger
import Preferences

/// https://platform.openai.com/docs/api-reference/responses/create
public actor OpenAIResponsesRawService {
    struct CompletionAPIError: Error, Decodable, LocalizedError {
        struct ErrorDetail: Decodable {
            var message: String
            var type: String?
            var param: String?
            var code: String?
        }

        struct MistralAIErrorMessage: Decodable {
            struct Detail: Decodable {
                var msg: String?
            }

            var message: String?
            var msg: String?
            var detail: [Detail]?
        }

        enum Message {
            case raw(String)
            case mistralAI(MistralAIErrorMessage)
        }

        var error: ErrorDetail?
        var message: Message

        var errorDescription: String? {
            if let message = error?.message { return message }
            switch message {
            case let .raw(string):
                return string
            case let .mistralAI(mistralAIErrorMessage):
                return mistralAIErrorMessage.message
                    ?? mistralAIErrorMessage.msg
                    ?? mistralAIErrorMessage.detail?.first?.msg
                    ?? "Unknown Error"
            }
        }

        enum CodingKeys: String, CodingKey {
            case error
            case message
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            error = try container.decode(ErrorDetail.self, forKey: .error)
            message = {
                if let e = try? container.decode(MistralAIErrorMessage.self, forKey: .message) {
                    return CompletionAPIError.Message.mistralAI(e)
                }
                if let e = try? container.decode(String.self, forKey: .message) {
                    return .raw(e)
                }
                return .raw("Unknown Error")
            }()
        }
    }

    var apiKey: String
    var endpoint: URL
    var requestBody: [String: Any]
    var model: ChatModel
    let requestModifier: ((inout URLRequest) -> Void)?

    public init(
        apiKey: String,
        model: ChatModel,
        endpoint: URL,
        requestBody: Data,
        requestModifier: ((inout URLRequest) -> Void)? = nil
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.requestBody = (
            try? JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        ) ?? [:]
        self.requestBody["model"] = model.info.modelName
        self.model = model
        self.requestModifier = requestModifier
    }

    public func callAsFunction() async throws
        -> URLSession.AsyncBytes
    {
        requestBody["stream"] = true
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(
            withJSONObject: requestBody,
            options: []
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        Self.setupAppInformation(&request)
        await Self.setupAPIKey(&request, model: model, apiKey: apiKey)
        Self.setupGitHubCopilotVisionField(&request, model: model)
        await Self.setupExtraHeaderFields(&request, model: model, apiKey: apiKey)
        requestModifier?(&request)

        let (result, response) = try await URLSession.shared.bytes(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw ChatGPTServiceError.responseInvalid
        }

        guard response.statusCode == 200 else {
            let text = try await result.lines.reduce(into: "") { partialResult, current in
                partialResult += current
            }
            guard let data = text.data(using: .utf8)
            else { throw ChatGPTServiceError.responseInvalid }
            if response.statusCode == 403 {
                throw ChatGPTServiceError.unauthorized(text)
            }
            let decoder = JSONDecoder()
            let error = try? decoder.decode(CompletionAPIError.self, from: data)
            throw error ?? ChatGPTServiceError.otherError(
                text +
                    "\n\nPlease check your model settings, some capabilities may not be supported by the model."
            )
        }

        return result
    }

    public func callAsFunction() async throws -> Data {
        let stream: URLSession.AsyncBytes = try await callAsFunction()

        return try await stream.reduce(into: Data()) { partialResult, byte in
            partialResult.append(byte)
        }
    }

    static func setupAppInformation(_ request: inout URLRequest) {
        if #available(macOS 13.0, *) {
            if request.url?.host == "openrouter.ai" {
                request.setValue("Copilot for Xcode", forHTTPHeaderField: "X-Title")
                request.setValue(
                    "https://github.com/intitni/CopilotForXcode",
                    forHTTPHeaderField: "HTTP-Referer"
                )
            }
        } else {
            if request.url?.host == "openrouter.ai" {
                request.setValue("Copilot for Xcode", forHTTPHeaderField: "X-Title")
                request.setValue(
                    "https://github.com/intitni/CopilotForXcode",
                    forHTTPHeaderField: "HTTP-Referer"
                )
            }
        }
    }

    static func setupAPIKey(_ request: inout URLRequest, model: ChatModel, apiKey: String) async {
        if !apiKey.isEmpty {
            switch model.format {
            case .openAI:
                if !model.info.openAIInfo.organizationID.isEmpty {
                    request.setValue(
                        model.info.openAIInfo.organizationID,
                        forHTTPHeaderField: "OpenAI-Organization"
                    )
                }

                if !model.info.openAIInfo.projectID.isEmpty {
                    request.setValue(
                        model.info.openAIInfo.projectID,
                        forHTTPHeaderField: "OpenAI-Project"
                    )
                }

                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            case .openAICompatible:
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            case .azureOpenAI:
                request.setValue(apiKey, forHTTPHeaderField: "api-key")
            case .gitHubCopilot:
                break
            case .googleAI:
                assertionFailure("Unsupported")
            case .ollama:
                assertionFailure("Unsupported")
            case .claude:
                assertionFailure("Unsupported")
            }
        }

        if model.format == .gitHubCopilot,
           let token = try? await GitHubCopilotExtension.fetchToken()
        {
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

    static func setupGitHubCopilotVisionField(_ request: inout URLRequest, model: ChatModel) {
        if model.info.supportsImage {
            request.setValue("true", forHTTPHeaderField: "copilot-vision-request")
        }
    }

    static func setupExtraHeaderFields(
        _ request: inout URLRequest,
        model: ChatModel,
        apiKey: String
    ) async {
        let parser = HeaderValueParser()
        for field in model.info.customHeaderInfo.headers where !field.key.isEmpty {
            let value = await parser.parse(
                field.value,
                context: .init(modelName: model.info.modelName, apiKey: apiKey)
            )
            request.setValue(value, forHTTPHeaderField: field.key)
        }
    }
}

