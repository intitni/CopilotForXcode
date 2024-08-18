import ChatBasic
import Foundation
import XCTest

@testable import OpenAIService

class AutoManagedChatGPTMemoryRetrievedContentTests: XCTestCase {
    let separator = String(repeating: "=", count: 32)

    func ref(_ text: String) -> ChatMessage.Reference {
        .init(
            title: "",
            content: text,
            kind: .text
        )
    }

    func test_retrieved_content_when_the_context_window_is_large_enough() async {
        let strategy = Strategy()

        let memory = AutoManagedChatGPTMemory(
            systemPrompt: "",
            configuration: UserPreferenceChatGPTConfiguration(),
            functionProvider: EmptyFunctionProvider()
        )

        await memory.mutateRetrievedContent([
            ref("A"), ref("B"), ref("C"), ref("D"), ref("E"),
        ])

        let fullContent = """
        Here are the information you know about the system and the project, \
        separated by \(separator)

        \(separator)[DOCUMENT 0]

        A

        \(separator)[DOCUMENT 1]

        B

        \(separator)[DOCUMENT 2]

        C

        \(separator)[DOCUMENT 3]

        D

        \(separator)[DOCUMENT 4]

        E
        """

        let maxTokenCount = await strategy.countToken(.init(role: .user, content: fullContent))

        let result = await memory.generateRetrievedContentMessage(
            maxTokenCount: maxTokenCount,
            strategy: strategy
        )

        XCTAssertEqual(result.references.count, 5)
        XCTAssertEqual(result.retrievedContent.role, .user)
        XCTAssertEqual(result.retrievedContent.content, """
        Here are the information you know about the system and the project, \
        separated by \(separator)

        \(separator)[DOCUMENT 0]

        A

        \(separator)[DOCUMENT 1]

        B

        \(separator)[DOCUMENT 2]

        C

        \(separator)[DOCUMENT 3]

        D

        \(separator)[DOCUMENT 4]

        E
        """)
    }

    func test_retrieved_content_when_the_context_window_is_just_not_large_enough() async {
        let strategy = Strategy()

        let memory = AutoManagedChatGPTMemory(
            systemPrompt: "",
            configuration: UserPreferenceChatGPTConfiguration(),
            functionProvider: EmptyFunctionProvider()
        )

        await memory.mutateRetrievedContent([
            ref("A"), ref("B"), ref("C"), ref("D"), ref("E"),
        ])

        let fullContent = """
        Here are the information you know about the system and the project, \
        separated by \(separator)

        \(separator)[DOCUMENT 0]

        A

        \(separator)[DOCUMENT 1]

        B

        \(separator)[DOCUMENT 2]

        C

        \(separator)[DOCUMENT 3]

        D

        \(separator)[DOCUMENT 4]

        E
        """

        let maxTokenCount = await strategy.countToken(.init(role: .user, content: fullContent))

        let result = await memory.generateRetrievedContentMessage(
            maxTokenCount: maxTokenCount - 1,
            strategy: strategy
        )

        XCTAssertEqual(result.references.count, 4)
        XCTAssertEqual(result.retrievedContent.role, .user)
        XCTAssertEqual(result.retrievedContent.content, """
        Here are the information you know about the system and the project, \
        separated by \(separator)

        \(separator)[DOCUMENT 0]

        A

        \(separator)[DOCUMENT 1]

        B

        \(separator)[DOCUMENT 2]

        C

        \(separator)[DOCUMENT 3]

        D
        """)
    }

    func test_retrieved_content_when_the_context_window_can_take_only_one_document() async {
        let strategy = Strategy()

        let memory = AutoManagedChatGPTMemory(
            systemPrompt: "",
            configuration: UserPreferenceChatGPTConfiguration(),
            functionProvider: EmptyFunctionProvider()
        )

        await memory.mutateRetrievedContent([
            ref("A"), ref("B"), ref("C"), ref("D"), ref("E"),
        ])

        let fullContent = """
        Here are the information you know about the system and the project, \
        separated by \(separator)

        \(separator)[DOCUMENT 0]

        A
        """

        let maxTokenCount = await strategy.countToken(.init(role: .user, content: fullContent))

        let result = await memory.generateRetrievedContentMessage(
            maxTokenCount: maxTokenCount + 1,
            strategy: strategy
        )

        XCTAssertEqual(result.references.count, 1)
        XCTAssertEqual(result.retrievedContent.role, .user)
        XCTAssertEqual(result.retrievedContent.content, """
        Here are the information you know about the system and the project, \
        separated by \(separator)

        \(separator)[DOCUMENT 0]

        A
        """)
    }

    func test_retrieved_content_when_the_context_window_empty() async {
        let strategy = Strategy()

        let memory = AutoManagedChatGPTMemory(
            systemPrompt: "",
            configuration: UserPreferenceChatGPTConfiguration(),
            functionProvider: EmptyFunctionProvider()
        )

        await memory.mutateRetrievedContent([
            ref("A"), ref("B"), ref("C"), ref("D"), ref("E"),
        ])

        let result = await memory.generateRetrievedContentMessage(
            maxTokenCount: 0,
            strategy: strategy
        )

        XCTAssertEqual(result.references.count, 0)
        XCTAssertEqual(result.retrievedContent.role, .user)
        XCTAssertEqual(result.retrievedContent.content, "")
    }
}

private struct EmptyFunctionProvider: ChatGPTFunctionProvider {
    var functions: [any ChatGPTFunction] { [] }
    var functionCallStrategy: FunctionCallStrategy? { nil }
}

private struct Strategy: AutoManagedChatGPTMemoryStrategy {
    func countToken(_ message: OpenAIService.ChatMessage) async -> Int {
        message.content?.count ?? 0
    }

    func countToken<F>(_: F) async -> Int where F: ChatGPTFunction {
        0
    }
}

