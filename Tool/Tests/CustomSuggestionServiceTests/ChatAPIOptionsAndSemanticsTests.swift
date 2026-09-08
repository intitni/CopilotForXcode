import AIModel
import Foundation
import Preferences
import XCTest

@testable import CustomSuggestionService

final class ChatAPIOptionsAndSemanticsTests: XCTestCase {
    func test_responsesEndpoint_four_branches() {
        XCTAssertEqual(
            CodeCompletionService.responsesEndpoint(for: chatModel(baseURL: "")),
            "https://api.openai.com/v1/responses"
        )
        XCTAssertEqual(
            CodeCompletionService.responsesEndpoint(for: chatModel(
                baseURL: "https://gw.example/v1/chat/completions",
                isFullURL: true
            )),
            "https://gw.example/v1/responses"
        )
        XCTAssertEqual(
            CodeCompletionService.responsesEndpoint(for: chatModel(
                baseURL: "https://gw.example/custom/responses",
                isFullURL: true
            )),
            "https://gw.example/custom/responses"
        )
        XCTAssertEqual(
            CodeCompletionService.responsesEndpoint(for: chatModel(
                baseURL: "https://gw.example/",
                isFullURL: false
            )),
            "https://gw.example/v1/responses"
        )
        XCTAssertEqual(
            CodeCompletionService.responsesEndpoint(for: chatModel(
                baseURL: "https://gw.example/v1/chat/completions/",
                isFullURL: true
            )),
            "https://gw.example/v1/responses"
        )
        XCTAssertEqual(
            CodeCompletionService.responsesEndpoint(for: chatModel(
                baseURL: "https://gw.example/v1/chat/completions?api-version=1",
                isFullURL: true
            )),
            "https://gw.example/v1/responses?api-version=1"
        )
        XCTAssertEqual(
            CodeCompletionService.responsesEndpoint(for: ChatModel(
                id: "id",
                name: "Test",
                format: .openAI,
                info: .init(
                    baseURL: "https://api.openai.com",
                    isFullURL: true,
                    modelName: "gpt-5.5"
                )
            )),
            "https://api.openai.com/v1/responses"
        )
    }

    func test_chatModelAPIOptions_per_id_read_write_and_legacy_migration() {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        ChatModelAPIOptions.update(
            .init(api: .responses, reasoningEffort: .high, reasoningTokenBudget: 2000),
            for: "model-a",
            defaults: defaults
        )
        let storedA = ChatModelAPIOptions.stored(for: "model-a", defaults: defaults)
        XCTAssertEqual(storedA.api, .responses)
        XCTAssertEqual(storedA.reasoningEffort, .high)
        XCTAssertEqual(storedA.reasoningTokenBudget, 2000)
        XCTAssertEqual(
            ChatModelAPIOptions.stored(for: "model-b", defaults: defaults),
            ChatModelAPIOptions()
        )

        let (legacyDefaults, legacySuite) = isolatedDefaults()
        defer { legacyDefaults.removePersistentDomain(forName: legacySuite) }
        legacyDefaults.set("responses", forKey: ChatModelAPIOptions.legacyOpenAIAPIKey)
        legacyDefaults.set("minimal", forKey: ChatModelAPIOptions.legacyReasoningEffortKey)

        let migrated = ChatModelAPIOptions.stored(for: "model-1", defaults: legacyDefaults)
        XCTAssertEqual(migrated.api, .responses)
        XCTAssertEqual(migrated.reasoningEffort, .minimal)
        XCTAssertNil(legacyDefaults.value(forKey: ChatModelAPIOptions.legacyOpenAIAPIKey))
        XCTAssertNil(legacyDefaults.value(forKey: ChatModelAPIOptions.legacyReasoningEffortKey))
        XCTAssertEqual(
            ChatModelAPIOptions.stored(for: "model-2", defaults: legacyDefaults).api,
            .chatCompletions
        )
    }

    func test_chat_request_body_legacy_and_reasoning_shapes() throws {
        let messages = [OpenAIService.Message(role: .user, content: "hi")]
        let legacy = OpenAIService.makeChatCompletionRequestBody(
            modelName: "gpt-5.5",
            messages: messages,
            temperature: 0.2,
            stopWords: ["\n\n"],
            maxToken: 200,
            reasoningEffort: nil,
            reasoningTokenBudget: 1500
        )
        let legacyJSON = try jsonObject(legacy)
        XCTAssertEqual(legacyJSON["temperature"] as? Double, 0.2)
        XCTAssertEqual(legacyJSON["stop"] as? [String], ["\n\n"])
        XCTAssertEqual((legacyJSON["max_tokens"] as? NSNumber)?.intValue, 200)
        XCTAssertNil(legacyJSON["max_completion_tokens"])
        XCTAssertNil(legacyJSON["reasoning_effort"])

        let reasoning = OpenAIService.makeChatCompletionRequestBody(
            modelName: "gpt-5.5",
            messages: messages,
            temperature: 0.2,
            stopWords: ["\n\n"],
            maxToken: 200,
            reasoningEffort: .high,
            reasoningTokenBudget: 1500
        )
        let reasoningJSON = try jsonObject(reasoning)
        XCTAssertNil(reasoningJSON["temperature"])
        XCTAssertNil(reasoningJSON["stop"])
        XCTAssertNil(reasoningJSON["max_tokens"])
        XCTAssertEqual((reasoningJSON["max_completion_tokens"] as? NSNumber)?.intValue, 1700)
        XCTAssertEqual(reasoningJSON["reasoning_effort"] as? String, "high")

        let minimal = OpenAIService.makeChatCompletionRequestBody(
            modelName: "gpt-5.5",
            messages: messages,
            temperature: 0.2,
            stopWords: ["\n\n"],
            maxToken: 200,
            reasoningEffort: .minimal,
            reasoningTokenBudget: 1500
        )
        let minimalJSON = try jsonObject(minimal)
        XCTAssertEqual((minimalJSON["max_completion_tokens"] as? NSNumber)?.intValue, 200)
        XCTAssertEqual(minimalJSON["reasoning_effort"] as? String, "minimal")
    }

    func test_responses_request_body_store_false_and_temperature_when_effort_nil() throws {
        let withoutEffort = OpenAIResponsesService.makeRequestBody(
            modelName: "gpt-5.5",
            input: [],
            instructions: "complete",
            maxToken: 200,
            reasoningEffort: nil,
            reasoningTokenBudget: 1500
        )
        let json = try jsonObject(withoutEffort)
        XCTAssertEqual(json["store"] as? Bool, false)
        XCTAssertEqual(json["temperature"] as? Double, 0.2)
        XCTAssertEqual((json["max_output_tokens"] as? NSNumber)?.intValue, 200)
        XCTAssertNil(json["reasoning"])

        let withEffort = OpenAIResponsesService.makeRequestBody(
            modelName: "gpt-5.5",
            input: [],
            instructions: "complete",
            maxToken: 200,
            reasoningEffort: .xhigh,
            reasoningTokenBudget: 1500
        )
        let effortJSON = try jsonObject(withEffort)
        XCTAssertEqual(effortJSON["store"] as? Bool, false)
        XCTAssertNil(effortJSON["temperature"])
        XCTAssertEqual((effortJSON["max_output_tokens"] as? NSNumber)?.intValue, 1700)
        XCTAssertEqual((effortJSON["reasoning"] as? [String: Any])?["effort"] as? String, "xhigh")
    }

    func test_anthropic_request_body_contains_output_config_effort() throws {
        let body = AnthropicService.makeMessageRequestBody(
            modelName: "claude-3-5-sonnet-latest",
            messages: [.init(role: .user, content: "hi")],
            systemPrompt: "complete",
            maxToken: 200,
            temperature: 0.2,
            stopSequences: ["\n\n"],
            reasoningEffort: .minimal
        )
        let json = try jsonObject(body)
        XCTAssertEqual(
            (json["output_config"] as? [String: Any])?["effort"] as? String,
            "low"
        )

        let high = AnthropicService.makeMessageRequestBody(
            modelName: "claude-3-5-sonnet-latest",
            messages: [.init(role: .user, content: "hi")],
            systemPrompt: nil,
            maxToken: 200,
            temperature: 0.2,
            stopSequences: nil,
            reasoningEffort: .xhigh
        )
        XCTAssertEqual(
            (try jsonObject(high)["output_config"] as? [String: Any])?["effort"] as? String,
            "high"
        )
    }

    func test_client_stop_word_truncation() async throws {
        let stream = AsyncThrowingStream<String, Error> { continuation in
            continuation.yield("hello")
            continuation.yield(" world")
            continuation.yield("\n\n")
            continuation.yield("more")
            continuation.finish()
        }
        let limiter = StreamLineLimiter(lineLimit: 0, strategy: NeverStreamStopStrategy())
        let result = try await collectCompletion(
            from: stream,
            stopWords: ["\n\n"],
            limiter: limiter
        )
        XCTAssertEqual(result, "hello world")
    }

    func test_client_stop_word_truncation_split_across_tokens() async throws {
        let stream = AsyncThrowingStream<String, Error> { continuation in
            continuation.yield("hello")
            continuation.yield("\n")
            continuation.yield("\nmore")
            continuation.yield("tail")
            continuation.finish()
        }
        let limiter = StreamLineLimiter(lineLimit: 0, strategy: NeverStreamStopStrategy())
        let result = try await collectCompletion(
            from: stream,
            stopWords: ["\n\n"],
            limiter: limiter
        )
        XCTAssertEqual(result, "hello")
    }

    func test_azure_format_reasoning_request_body_contains_max_completion_tokens() throws {
        let chat = ChatModel(
            id: "azure-chat",
            name: "Azure Chat",
            format: .azureOpenAI,
            info: .init(
                apiKeyName: "azure",
                baseURL: "https://example.openai.azure.com",
                maxTokens: 8000,
                modelName: "gpt-4o"
            )
        )
        XCTAssertEqual(
            chat.endpoint,
            OpenAIService.azureEndpoint(
                baseURL: chat.info.baseURL,
                deployment: chat.info.modelName,
                endpoint: .chatCompletion
            )
        )
        XCTAssertEqual(
            OpenAIService.azureEndpoint(
                baseURL: "",
                deployment: "gpt-4o",
                endpoint: .chatCompletion
            ),
            ""
        )
        XCTAssertEqual(
            try OpenAIService.resolveURL(
                url: chat.endpoint,
                authentication: .apiKeyHeader,
                endpoint: .chatCompletion
            ).absoluteString,
            chat.endpoint
        )
        XCTAssertTrue(chat.endpoint.contains("api-version=2024-09-01-preview"))

        XCTAssertThrowsError(
            try OpenAIService.resolveURL(
                url: "",
                authentication: .apiKeyHeader,
                endpoint: .chatCompletion
            )
        ) { error in
            XCTAssertEqual(
                error.localizedDescription,
                OpenAIService.missingAzureEndpointMessage
            )
        }
        XCTAssertThrowsError(
            try OpenAIService.resolveURL(
                url: "https://api.openai.com/v1/chat/completions",
                authentication: .apiKeyHeader,
                endpoint: .chatCompletion
            )
        ) { error in
            XCTAssertEqual(
                error.localizedDescription,
                OpenAIService.missingAzureEndpointMessage
            )
        }

        let completion = CompletionModel(
            id: "azure-completion",
            name: "Azure Completion",
            format: .azureOpenAI,
            info: .init(
                baseURL: "https://example.openai.azure.com",
                modelName: "gpt-35-turbo-instruct"
            )
        )
        XCTAssertEqual(
            completion.endpoint,
            OpenAIService.azureEndpoint(
                baseURL: completion.info.baseURL,
                deployment: completion.info.modelName,
                endpoint: .completion
            )
        )

        let body = OpenAIService.makeChatCompletionRequestBody(
            modelName: chat.info.modelName,
            messages: [.init(role: .user, content: "hi")],
            temperature: 0.2,
            stopWords: ["\n\n"],
            maxToken: 200,
            reasoningEffort: .high,
            reasoningTokenBudget: 1500
        )
        let json = try jsonObject(body)
        XCTAssertEqual((json["max_completion_tokens"] as? NSNumber)?.intValue, 1700)
        XCTAssertEqual(json["reasoning_effort"] as? String, "high")
        XCTAssertNil(json["max_tokens"])
        XCTAssertNil(json["temperature"])
        XCTAssertNil(json["stop"])
    }

    func test_chatAPIOptions_current_defaults_invalid_raw_and_empty_key_filter() async {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let model = ChatModel(
            id: "model-defaults",
            name: "Test",
            format: .openAI,
            info: .init(
                modelName: "gpt-5.5",
                customHeaderInfo: .init(headers: [
                    .init(key: "", value: "skip-me"),
                    .init(key: "X-Ok", value: "yes"),
                ])
            )
        )

        let options = await ChatAPIOptions.current(
            for: model,
            apiKey: "sk",
            defaults: defaults
        )
        XCTAssertEqual(options.api, .chatCompletions)
        XCTAssertNil(options.reasoningEffort)
        XCTAssertEqual(options.reasoningTokenBudget, 1500)
        XCTAssertEqual(options.extraHeaders.map(\.name), ["X-Ok"])
        XCTAssertEqual(options.extraHeaders.first?.value, "yes")

        defaults.set(
            "not-json",
            forKey: UserDefaultPreferenceKeys().customSuggestionChatModelAPIOptions.key
        )
        let invalidStored = await ChatAPIOptions.current(
            for: model,
            apiKey: "sk",
            defaults: defaults
        )
        XCTAssertEqual(invalidStored.api, .chatCompletions)
        XCTAssertNil(invalidStored.reasoningEffort)
        XCTAssertEqual(invalidStored.reasoningTokenBudget, 1500)

        let (legacyDefaults, legacySuite) = isolatedDefaults()
        defer { legacyDefaults.removePersistentDomain(forName: legacySuite) }
        legacyDefaults.set("not-an-api", forKey: ChatModelAPIOptions.legacyOpenAIAPIKey)
        legacyDefaults.set("not-an-effort", forKey: ChatModelAPIOptions.legacyReasoningEffortKey)
        let migrated = ChatModelAPIOptions.stored(for: "model-defaults", defaults: legacyDefaults)
        XCTAssertEqual(migrated.api, .chatCompletions)
        XCTAssertNil(migrated.reasoningEffort)
        XCTAssertNil(OpenAIChatAPI(rawValue: "not-an-api"))
        XCTAssertNil(ReasoningEffort(rawValue: "not-an-effort"))
    }

    func test_customBodyInfo_joinJSON_merge() throws {
        let original = Data(#"{"model":"a","stream":true}"#.utf8)
        let merged = CompletionJSON.mergeCustomBody(
            original,
            jsonBody: #"{"foo":1,"model":"b"}"#
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: merged) as? [String: Any])
        XCTAssertEqual((json["foo"] as? NSNumber)?.intValue, 1)
        XCTAssertEqual(json["model"] as? String, "b")
        XCTAssertEqual(json["stream"] as? Bool, true)
        XCTAssertEqual(
            CompletionJSON.mergeCustomBody(original, jsonBody: "  "),
            original
        )
    }
}

private func jsonObject<T: Encodable>(_ value: T) throws -> [String: Any] {
    let data = try JSONEncoder().encode(value)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func isolatedDefaults() -> (UserDefaults, String) {
    let name = "wp3.semantics.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return (defaults, name)
}

private func chatModel(baseURL: String, isFullURL: Bool = false) -> ChatModel {
    ChatModel(
        id: "id",
        name: "Test",
        format: .openAICompatible,
        info: .init(baseURL: baseURL, isFullURL: isFullURL, modelName: "gpt-5.5")
    )
}
