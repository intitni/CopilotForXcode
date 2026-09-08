import AIModel
import CopilotForXcodeKit
import Foundation
import Preferences
import XCTest

@testable import CustomSuggestionService

class ChatAPIStreamParsingTests: XCTestCase {
    // MARK: Responses API

    func test_responses_delta_event() throws {
        let line = #"data: {"type":"response.output_text.delta","item_id":"msg_1","delta":"Hel"}"#
        let result = try OpenAIResponsesService.parseStreamLine(line)
        XCTAssertEqual(result.chunk?.text, "Hel")
        XCTAssertFalse(result.done)
    }

    func test_responses_ignores_lines_without_text() throws {
        for line in [
            "",
            "event: response.output_text.delta",
            ": keep-alive",
            #"data: {"type":"response.created","response":{"id":"resp_1","object":"response"}}"#,
            #"data: {"type":"response.output_text.done","text":"Hello"}"#,
        ] {
            let result = try OpenAIResponsesService.parseStreamLine(line)
            XCTAssertNil(result.chunk?.text, line)
            XCTAssertFalse(result.done, line)
        }
    }

    func test_responses_completed_event_finishes_the_stream() throws {
        let line = #"data: {"type":"response.completed","response":{"id":"resp_1","object":"response","status":"completed"}}"#
        let result = try OpenAIResponsesService.parseStreamLine(line)
        XCTAssertNil(result.chunk?.text)
        XCTAssertTrue(result.done)
        XCTAssertTrue(try OpenAIResponsesService.parseStreamLine("data: [DONE]").done)
    }

    func test_responses_incomplete_finishes_stream() throws {
        let truncated = #"data: {"type":"response.incomplete","response":{"id":"resp_truncated","object":"response","status":"incomplete","incomplete_details":{"reason":"max_output_tokens"}}}"#
        let result = try OpenAIResponsesService.parseStreamLine(truncated)
        XCTAssertNil(result.chunk?.text)
        XCTAssertTrue(result.done)

        let other = #"data: {"type":"response.incomplete","response":{"id":"resp_other","object":"response","status":"incomplete","incomplete_details":{"reason":"content_filter"}}}"#
        XCTAssertTrue(try OpenAIResponsesService.parseStreamLine(other).done)
    }

    func test_responses_error_events_throw() {
        XCTAssertThrowsError(try OpenAIResponsesService.parseStreamLine(
            #"data: {"type":"error","code":"rate_limit","message":"slow down"}"#
        )) { XCTAssertEqual($0.localizedDescription, "slow down") }
        XCTAssertThrowsError(try OpenAIResponsesService.parseStreamLine(
            #"data: {"type":"response.failed","response":{"object":"response","status":"failed","error":{"message":"boom"}}}"#
        )) { XCTAssertEqual($0.localizedDescription, "boom") }
        XCTAssertThrowsError(try OpenAIResponsesService.parseStreamLine(
            #"data: {"error":{"message":"boom"}}"#
        )) { XCTAssertEqual($0.localizedDescription, "boom") }
    }

    func test_responses_non_streaming_body() throws {
        let body = """
        {"id":"resp_abc123","object":"response","model":"gpt-5.5","status":"completed",\
        "output":[{"type":"reasoning","summary":[]},\
        {"type":"message","role":"assistant","content":[{"type":"output_text","text":"Hel"},{"type":"output_text","text":"lo!"}]}],\
        "usage":{"input_tokens":12,"output_tokens":45,"total_tokens":57}}
        """
        let result = try OpenAIResponsesService.parseStreamLine(body)
        XCTAssertEqual(result.chunk?.text, "Hello!")
        XCTAssertTrue(result.done)
    }

    // MARK: Chat Completions API

    func test_chatCompletions_delta_and_done_marker() throws {
        let delta = #"data: {"id":"chatcmpl-1","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":"Hi"},"finish_reason":null}]}"#
        let result = try OpenAIService.parseChatCompletionsStreamLine(delta)
        XCTAssertEqual(result.chunk?.choices?.first?.delta?.content, "Hi")
        XCTAssertFalse(result.done)

        let finished = #"data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}"#
        XCTAssertTrue(try OpenAIService.parseChatCompletionsStreamLine(finished).done)
        XCTAssertTrue(try OpenAIService.parseChatCompletionsStreamLine("data: [DONE]").done)
        XCTAssertFalse(try OpenAIService.parseChatCompletionsStreamLine("").done)
    }

    func test_chatCompletions_non_streaming_body() throws {
        let body = #"{"id":"chatcmpl-abc123","object":"chat.completion","model":"gpt-5.5","choices":[{"index":0,"message":{"role":"assistant","content":"Hello! How can I help you today?"},"finish_reason":"stop"}]}"#
        let result = try OpenAIService.parseChatCompletionsStreamLine(body)
        XCTAssertEqual(result.chunk?.choices?.first?.delta?.content, "Hello! How can I help you today?")
        XCTAssertTrue(result.done)
    }

    // MARK: Helpers

    func test_sse_payload() {
        XCTAssertEqual(SSELine.payload(of: "data: {}"), "{}")
        XCTAssertEqual(SSELine.payload(of: "data:{}"), "{}")
        XCTAssertEqual(SSELine.payload(of: "{\"a\":1}"), "{\"a\":1}")
        XCTAssertNil(SSELine.payload(of: "event: x"))
        XCTAssertNil(SSELine.payload(of: "id: 1"))
        XCTAssertNil(SSELine.payload(of: "   "))
    }

    func test_header_placeholders() async {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let model = ChatModel(
            id: "header-model",
            name: "Headers",
            format: .openAI,
            info: .init(
                modelName: "gpt-5.5",
                customHeaderInfo: .init(headers: [
                    .init(key: "X-Auth", value: "Bearer {{api_key}} for {{model_name}}"),
                    .init(key: "Bad Name", value: "nope"),
                    .init(key: "X-NL", value: "a\nb"),
                ])
            )
        )
        let options = await ChatAPIOptions.current(
            for: model,
            apiKey: "sk-1",
            defaults: defaults
        )
        XCTAssertEqual(options.extraHeaders.map(\.name), ["X-Auth"])
        XCTAssertEqual(options.extraHeaders.first?.value, "Bearer sk-1 for gpt-5.5")
    }

    func test_parseCompletionsStreamLine_delta_done_and_error() throws {
        let delta = #"data: {"id":"cmpl-1","object":"text_completion","choices":[{"text":"foo","index":0,"finish_reason":null}]}"#
        let result = try OpenAIService.parseCompletionsStreamLine(delta)
        XCTAssertEqual(result.chunk?.choices?.first?.text, "foo")
        XCTAssertFalse(result.done)

        XCTAssertTrue(try OpenAIService.parseCompletionsStreamLine("data: [DONE]").done)
        XCTAssertFalse(try OpenAIService.parseCompletionsStreamLine("").done)
        XCTAssertFalse(try OpenAIService.parseCompletionsStreamLine(": keepalive").done)

        let finished = #"data: {"choices":[{"text":"","index":0,"finish_reason":"stop"}]}"#
        XCTAssertTrue(try OpenAIService.parseCompletionsStreamLine(finished).done)

        XCTAssertThrowsError(try OpenAIService.parseCompletionsStreamLine(
            #"data: {"error":{"message":"boom"}}"#
        )) { error in
            guard case OpenAIService.Error.apiError(let message) = error else {
                return XCTFail("expected apiError, got \(error)")
            }
            XCTAssertEqual(message, "boom")
        }
    }

    func test_chatCompletions_error_line_throws_apiError() {
        XCTAssertThrowsError(try OpenAIService.parseChatCompletionsStreamLine(
            #"data: {"error":{"message":"boom"}}"#
        )) { error in
            XCTAssertEqual(error.localizedDescription, "boom")
            guard case OpenAIService.Error.apiError(let message) = error else {
                return XCTFail("expected apiError, got \(error)")
            }
            XCTAssertEqual(message, "boom")
        }
    }

    func test_chatCompletions_pretty_printed_json_body_yields_message() async throws {
        let body = """
        {
          "id": "chatcmpl-abc123",
          "object": "chat.completion",
          "model": "gpt-5.5",
          "choices": [
            {
              "index": 0,
              "message": {
                "role": "assistant",
                "content": "Hello! How can I help you today?"
              },
              "finish_reason": "stop"
            }
          ]
        }
        """
        let parsed = try OpenAIService.parseChatCompletionsBody(
            body,
            url: URL(string: "https://api.example.invalid/v1/chat/completions")!
        )
        XCTAssertEqual(
            parsed.choices?.first?.delta?.content,
            "Hello! How can I help you today?"
        )

        let host = "wp2-openai-\(UUID().uuidString).invalid"
        CompletionStubURLProtocol.host = host
        CompletionStubURLProtocol.handler = { _ in
            (200, ["Content-Type": "application/json"], Data(body.utf8))
        }
        URLProtocol.registerClass(CompletionStubURLProtocol.self)
        defer { CompletionStubURLProtocol.reset() }

        let service = try OpenAIService(
            url: "http://\(host)/v1/chat/completions",
            endpoint: .chatCompletion,
            modelName: "gpt-5.5",
            contextWindow: 4096,
            maxToken: 64,
            apiKey: "sk-test"
        )
        let didFinish = expectation(description: "openai json body")
        let task = Task {
            do {
                let stream = try await service.getCompletion(ErrorVisibilityPrompt())
                var text = ""
                for try await part in stream {
                    text += part
                }
                XCTAssertEqual(text, "Hello! How can I help you today?")
            } catch {
                XCTFail("unexpected error: \(error)")
            }
            didFinish.fulfill()
        }
        await fulfillment(of: [didFinish], timeout: 2)
        task.cancel()
    }

    func test_azure_reasoning_request_sends_api_key_header_and_max_completion_tokens() async throws {
        let host = "wp6-azure-\(UUID().uuidString).invalid"
        final class Capture: @unchecked Sendable {
            var request: URLRequest?
        }
        let capture = Capture()
        CompletionStubURLProtocol.host = host
        CompletionStubURLProtocol.handler = { request in
            capture.request = request
            let sse = #"data: {"choices":[{"index":0,"delta":{"content":"ok"},"finish_reason":"stop"}]}"#
                + "\n\ndata: [DONE]\n"
            return (200, ["Content-Type": "text/event-stream"], Data(sse.utf8))
        }
        URLProtocol.registerClass(CompletionStubURLProtocol.self)
        defer { CompletionStubURLProtocol.reset() }

        let model = ChatModel(
            id: "azure",
            name: "Azure",
            format: .azureOpenAI,
            info: .init(
                apiKeyName: "azure",
                baseURL: "http://\(host)",
                modelName: "gpt-4o"
            )
        )
        // Same initializer as CodeCompletionService `.azureOpenAI` chat.
        let service = try OpenAIService(
            url: model.endpoint,
            endpoint: .chatCompletion,
            modelName: model.info.modelName,
            contextWindow: 8000,
            maxToken: 200,
            apiKey: "azure-key",
            authentication: .apiKeyHeader,
            reasoningEffort: .high,
            reasoningTokenBudget: 1500
        )
        let didFinish = expectation(description: "azure stream")
        let task = Task {
            do {
                let stream = try await service.getCompletion(ErrorVisibilityPrompt())
                var text = ""
                for try await part in stream {
                    text += part
                }
                XCTAssertEqual(text, "ok")
            } catch {
                XCTFail("unexpected error: \(error)")
            }
            didFinish.fulfill()
        }
        await fulfillment(of: [didFinish], timeout: 2)
        task.cancel()

        let request = try XCTUnwrap(capture.request)
        XCTAssertEqual(request.value(forHTTPHeaderField: "api-key"), "azure-key")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        let requestURL = try XCTUnwrap(request.url)
        XCTAssertTrue(
            requestURL.path.contains("/openai/deployments/"),
            requestURL.path
        )
        XCTAssertTrue(
            requestURL.path.hasSuffix("/chat/completions"),
            requestURL.path
        )
        XCTAssertEqual(
            URLComponents(url: requestURL, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "api-version" })?.value,
            "2024-09-01-preview"
        )
        let body = try XCTUnwrap(httpBody(of: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual((json["max_completion_tokens"] as? NSNumber)?.intValue, 1700)
        XCTAssertEqual(json["reasoning_effort"] as? String, "high")
        XCTAssertNil(json["max_tokens"])
    }

    func test_tabby_http_500_throws_immediately() async {
        let host = "wp2-tabby-\(UUID().uuidString).invalid"
        CompletionStubURLProtocol.host = host
        CompletionStubURLProtocol.handler = { _ in
            (500, ["Content-Type": "application/json"], Data("{\"error\":\"nope\"}".utf8))
        }
        URLProtocol.registerClass(CompletionStubURLProtocol.self)
        defer { CompletionStubURLProtocol.reset() }

        let service = TabbyService(
            url: "http://\(host)/v1/completions",
            authorizationMode: .none
        )
        let didThrow = expectation(description: "tabby throws")
        let task = Task {
            do {
                let stream = try await service.getCompletion(ErrorVisibilityPrompt())
                for try await _ in stream {
                    XCTFail("should not yield")
                }
                XCTFail("should throw")
            } catch {
                XCTAssertTrue(
                    error.localizedDescription.contains("HTTP 500"),
                    error.localizedDescription
                )
                didThrow.fulfill()
            }
        }
        await fulfillment(of: [didThrow], timeout: 2)
        task.cancel()
    }

    func test_asyncThrowingStream_wrapper_surfaces_task_error() async {
        struct Boom: Error {}
        let stream = AsyncThrowingStream<String, Swift.Error> { continuation in
            let task = Task {
                do {
                    throw Boom()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        do {
            for try await _ in stream {
                XCTFail("should not yield")
            }
            XCTFail("should throw")
        } catch is Boom {
            // Gemini's URLSession is owned by GoogleGenerativeAI and was not intercepted.
        } catch {
            XCTFail("unexpected \(error)")
        }
    }
}

private func isolatedDefaults() -> (UserDefaults, String) {
    let name = "wp3.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return (defaults, name)
}

private struct ErrorVisibilityPrompt: PromptStrategy {
    var systemPrompt: String { "complete" }
    var prefix: [String] { ["let x = "] }
    var suffix: [String] { [] }
    var relevantCodeSnippets: [RelevantCodeSnippet] { [] }
    var stopWords: [String] { [] }
    var language: CodeLanguage? { nil }

    func createPrompt(
        truncatedPrefix: [String],
        truncatedSuffix: [String],
        includedSnippets: [RelevantCodeSnippet]
    ) -> [PromptMessage] {
        [.init(role: .user, content: truncatedPrefix.joined())]
    }
}

private func httpBody(of request: URLRequest) -> Data? {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }
    var data = Data()
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
    defer { buffer.deallocate() }
    while stream.hasBytesAvailable {
        let count = stream.read(buffer, maxLength: 4096)
        if count <= 0 { break }
        data.append(buffer, count: count)
    }
    return data
}

private final class CompletionStubURLProtocol: URLProtocol {
    static var host: String?
    static var handler: ((URLRequest) throws -> (Int, [String: String], Data))?

    static func reset() {
        URLProtocol.unregisterClass(CompletionStubURLProtocol.self)
        host = nil
        handler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == host
    }

    override class func canInit(with task: URLSessionTask) -> Bool {
        guard let request = task.currentRequest else { return false }
        return canInit(with: request)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (status, headers, data) = try handler(request)
            let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
