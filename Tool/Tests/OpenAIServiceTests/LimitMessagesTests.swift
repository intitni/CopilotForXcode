import Foundation
import XCTest

@testable import OpenAIService

final class AutoManagedChatGPTMemoryTests: XCTestCase {
    func test_send_all_messages_if_not_reached_token_limit() async {
        let (messages, remainingTokens, memory) = await runService(
            systemPrompt: "system", messages: [
                "hi",
                "hello",
                "world",
            ], maxTokens: 10000, minimumReplyTokens: 200,
            maxNumberOfMessages: 0 // smaller than 1 means no limit
        )
        XCTAssertEqual(messages, [
            "system",
            "hi",
            "hello",
            "world",
        ])

        XCTAssertEqual(remainingTokens, 10000 - 12 - 6)
        let history = await memory.history
        XCTAssertEqual(history.map(\.tokensCount), [
            2,
            5,
            5,
        ])
    }

    func test_send_max_message_if_not_reached_token_limit() async {
        let (messages, remainingTokens, _) = await runService(
            systemPrompt: "system", messages: [
                "hi",
                "hello",
                "world",
            ], maxTokens: 10000, minimumReplyTokens: 200,
            maxNumberOfMessages: 2
        )
        XCTAssertEqual(messages, [
            "system",
            "hello",
            "world",
        ], "Count from end to start.")

        XCTAssertEqual(remainingTokens, 10000 - 10 - 6)
    }

    func test_reached_token_limit() async {
        let (messages, remainingTokens, _) = await runService(
            systemPrompt: "system", messages: [
                "hi",
                "hello",
                "world",
            ], maxTokens: 212, minimumReplyTokens: 200,
            maxNumberOfMessages: 100
        )
        XCTAssertEqual(messages, [
            "system",
            "world",
        ])

        XCTAssertEqual(remainingTokens, 201)
    }

    func test_minimum_reply_tokens_count() async {
        let (messages, remainingTokens, _) = await runService(
            systemPrompt: "system", messages: [
                "hi",
                "hello",
                "world",
            ],
            maxTokens: 200, minimumReplyTokens: 200,
            maxNumberOfMessages: 100
        )
        XCTAssertEqual(messages, [
            "system",
        ])

        XCTAssertEqual(remainingTokens, 200)
    }
}

class MockEncoder: TokenEncoder {
    func encode(text: String) -> [Int] {
        return .init(repeating: 0, count: text.count)
    }
}

private func runService(
    systemPrompt: String,
    messages: [String],
    maxTokens: Int,
    minimumReplyTokens: Int,
    maxNumberOfMessages: Int
) async -> (messages: [String], remainingTokens: Int?, memory: AutoManagedChatGPTMemory) {
    let configuration = UserPreferenceChatGPTConfiguration().overriding(.init(
        maxTokens: maxTokens,
        minimumReplyTokens: minimumReplyTokens
    ))
    let memory = AutoManagedChatGPTMemory(
        systemPrompt: systemPrompt,
        configuration: configuration
    )

    for message in messages {
        await memory.appendMessage(.init(role: .user, content: message))
    }

    let messages = await memory.generateSendingHistory(
        maxNumberOfMessages: maxNumberOfMessages,
        encoder: MockEncoder()
    )
    let remainingTokens = await memory.generateRemainingTokens(
        maxNumberOfMessages: maxNumberOfMessages,
        encoder: MockEncoder()
    )

    let contents = messages.map { $0.content ?? "" }
    return (contents, remainingTokens, memory)
}

