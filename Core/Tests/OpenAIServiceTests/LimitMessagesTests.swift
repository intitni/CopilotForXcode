import Foundation
import XCTest

@testable import OpenAIService

final class LimitMessagesTests: XCTestCase {
    func test_send_all_messages_if_not_reached_token_limit() async {
        let service = await createService(systemPrompt: "system", messages: [
            "hi",
            "hello",
            "world",
        ])

        let (messages, remainingTokens) = await runService(
            service,
            minimumReplyTokens: 200,
            maxNumberOfMessages: 0, // smaller than 1 means no limit
            maxTokens: 10000
        )
        XCTAssertEqual(messages, [
            "system",
            "hi",
            "hello",
            "world",
        ])
        
        XCTAssertEqual(remainingTokens, 10000 - 12 - 6)
    }
    
    func test_send_max_message_if_not_reached_token_limit() async {
        let service = await createService(systemPrompt: "system", messages: [
            "hi",
            "hello",
            "world",
        ])

        let (messages, remainingTokens) = await runService(
            service,
            minimumReplyTokens: 200,
            maxNumberOfMessages: 2,
            maxTokens: 10000
        )
        XCTAssertEqual(messages, [
            "system",
            "hello",
            "world",
        ], "Count from end to start.")
        
        XCTAssertEqual(remainingTokens, 10000 - 10 - 6)
    }
    
    func test_reached_token_limit() async {
        let service = await createService(systemPrompt: "system", messages: [
            "hi",
            "hello",
            "world",
        ])

        let (messages, remainingTokens) = await runService(
            service,
            minimumReplyTokens: 200,
            maxNumberOfMessages: 100,
            maxTokens: 212
        )
        XCTAssertEqual(messages, [
            "system",
            "world",
        ])
        
        XCTAssertEqual(remainingTokens, 201)
    }
    
    func test_minimum_reply_tokens_count() async {
        let service = await createService(systemPrompt: "system", messages: [
            "hi",
            "hello",
            "world",
        ])

        let (messages, remainingTokens) = await runService(
            service,
            minimumReplyTokens: 200,
            maxNumberOfMessages: 100,
            maxTokens: 200
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

private func createService(systemPrompt: String, messages: [String]) async -> ChatGPTService {
    let service = ChatGPTService(systemPrompt: systemPrompt)
    await service.mutateHistory { history in
        messages.forEach { message in
            history.append(.init(role: .user, content: message))
        }
    }
    return service
}

private func runService(
    _ service: ChatGPTService,
    minimumReplyTokens: Int,
    maxNumberOfMessages: Int,
    maxTokens: Int
) async -> (messages: [String], remainingTokens: Int) {
    let (messages, remainingTokens) = await service.combineHistoryWithSystemPrompt(
        minimumReplyTokens: minimumReplyTokens,
        maxNumberOfMessages: maxNumberOfMessages,
        maxTokens: maxTokens,
        encoder: MockEncoder()
    )

    return (messages.map(\.content), remainingTokens)
}
