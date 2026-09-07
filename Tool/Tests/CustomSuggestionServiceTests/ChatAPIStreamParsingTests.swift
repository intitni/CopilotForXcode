import Foundation
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

    func test_responses_error_events_throw() {
        XCTAssertThrowsError(try OpenAIResponsesService.parseStreamLine(
            #"data: {"type":"error","code":"rate_limit","message":"slow down"}"#
        )) { XCTAssertEqual($0.localizedDescription, "slow down") }
        XCTAssertThrowsError(try OpenAIResponsesService.parseStreamLine(
            #"data: {"type":"response.failed","response":{"object":"response","status":"failed","error":{"message":"boom"}}}"#
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

    func test_header_placeholders() {
        XCTAssertEqual(
            ChatAPIOptions.substitutePlaceholders(
                in: "Bearer {{api_key}} for {{model_name}}",
                modelName: "gpt-5.5",
                apiKey: "sk-1"
            ),
            "Bearer sk-1 for gpt-5.5"
        )
    }
}
