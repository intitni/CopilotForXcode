import ChatBasic
import Foundation
import TokenEncoder
import XCTest

@testable import OpenAIService

final class AutoManagedChatGPTMemoryLimitTests: XCTestCase {
    func test_send_all_messages_if_not_reached_token_limit() async {
        let (messages, memory) = await runService(
            systemPrompt: "system", 
            messages: [
                "hi",
                "hello",
                "world",
            ], 
            maxTokens: 10000,
            minimumReplyTokens: 200,
            maxNumberOfMessages: 0 // smaller than 1 means no limit
        )
        XCTAssertEqual(messages, [
            "system",
            "hi",
            "hello",
            "world",
        ])

//        XCTAssertEqual(remainingTokens, 10000 - 12 - 6)
//        let history = await memory.history
        
// token count caching is removed
//        XCTAssertEqual(history.map(\.tokensCount), [
//            5,
//            8,
//            8,
//        ])
    }

    func test_send_max_message_if_not_reached_token_limit() async {
        let (messages, _) = await runService(
            systemPrompt: "system", 
            messages: [
                "hi",
                "hello",
                "world",
            ], 
            maxTokens: 10000,
            minimumReplyTokens: 200,
            maxNumberOfMessages: 2
        )
        XCTAssertEqual(messages, [
            "system",
            "hello",
            "world",
        ], "Count from end to start.")

//        XCTAssertEqual(remainingTokens, 10000 - 10 - 6)
    }

    func test_reached_token_limit() async {
        let (messages, _) = await runService(
            systemPrompt: "system", 
            messages: [
                "hi",
                "hello",
                "world",
            ],
            maxTokens: 212,
            minimumReplyTokens: 200,
            maxNumberOfMessages: 100
        )
        XCTAssertEqual(messages, [
            "system",
        ])

//        XCTAssertEqual(remainingTokens, 201)
    }

    func test_minimum_reply_tokens_count() async {
        let (messages, _) = await runService(
            systemPrompt: "system", 
            messages: [
                "hi",
                "hello",
                "world",
            ],
            maxTokens: 200, 
            minimumReplyTokens: 200,
            maxNumberOfMessages: 100
        )
        XCTAssertEqual(messages, [
            "system",
        ])

//        XCTAssertEqual(remainingTokens, 200)
    }
}

class MockEncoder: TokenEncoder {
    func encode(text: String) -> [Int] {
        return .init(repeating: 0, count: text.count)
    }
}

struct MockStrategy: AutoManagedChatGPTMemoryStrategy {
    let encoder = MockEncoder()
    func countToken(_ message: ChatBasic.ChatMessage) async -> Int {
        await encoder.countToken(message)
    }

    func countToken<F>(_: F) async -> Int where F: ChatBasic.ChatGPTFunction {
        0
    }

    func reformat(_ prompt: OpenAIService.ChatGPTPrompt) async -> OpenAIService.ChatGPTPrompt {
        prompt
    }
}

private func runService(
    systemPrompt: String,
    messages: [String],
    maxTokens: Int,
    minimumReplyTokens: Int,
    maxNumberOfMessages: Int
) async -> (messages: [String], memory: AutoManagedChatGPTMemory) {
    let configuration = UserPreferenceChatGPTConfiguration().overriding(.init(
        maxTokens: maxTokens,
        minimumReplyTokens: minimumReplyTokens
    ))
    let memory = AutoManagedChatGPTMemory(
        systemPrompt: systemPrompt,
        configuration: configuration,
        functionProvider: NoChatGPTFunctionProvider(),
        maxNumberOfMessages: maxNumberOfMessages
    )

    for message in messages {
        await memory.appendMessage(.init(role: .user, content: message))
    }

    let messages = await memory.generateSendingHistory(
        strategy: MockStrategy()
    )

    let contents = messages.history.map { $0.content ?? "" }
    return (contents, memory)
}

