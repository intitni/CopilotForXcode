import Foundation
import GoogleGenerativeAI
import XCTest

@testable import OpenAIService

class GoogleAIChatCompletionsAPITests: XCTestCase {
    let convert = GoogleAIChatCompletionsService.convertMessages

    func test_top_system_prompt_should_convert_to_user_message_that_does_not_merge_with_others() {
        let prompt: [ChatCompletionsRequestBody.Message] = [
            .init(role: .system, content: "SystemPrompt"),
            .init(role: .user, content: "A"),
            .init(role: .assistant, content: "B"),
            .init(role: .user, content: "Hello"),
        ]

        let expected: [ChatCompletionsRequestBody.Message] = [
            .init(role: .user, content: """
            System Prompt:
            SystemPrompt
            """),
            .init(role: .assistant, content: "Got it. Let's start our conversation."),
            .init(role: .user, content: "A"),
            .init(role: .assistant, content: "B"),
            .init(role: .user, content: "Hello"),
        ]

        let converted = convert(prompt)

        XCTAssertEqual(
            converted.map { $0.parts.reduce("") { $0 + ($1.text ?? "") } },
            expected.map(\.content)
        )
        XCTAssertEqual(
            converted.map(\.role),
            expected.map(\.role).map(ModelContent.convertRole(_:))
        )
    }

    func test_adjacent_same_role_messages_should_be_merged_except_for_the_last_user_message() {
        let prompt: [ChatCompletionsRequestBody.Message] = [
            .init(role: .system, content: "SystemPrompt"),
            .init(role: .user, content: "A"),
            .init(role: .user, content: "B"),
            .init(role: .user, content: "C"),
            .init(role: .assistant, content: "D"),
            .init(role: .assistant, content: "E"),
            .init(role: .assistant, content: "F"),
            .init(role: .user, content: "World"),
        ]

        let expected: [ChatCompletionsRequestBody.Message] = [
            .init(role: .user, content: """
            System Prompt:
            SystemPrompt
            """),
            .init(role: .assistant, content: "Got it. Let's start our conversation."),
            .init(role: .user, content: """
            A

            ======

            B

            ======

            C
            """),
            .init(role: .assistant, content: """
            D

            ======

            E

            ======

            F
            """),
            .init(role: .user, content: "World"),
        ]

        let converted = convert(prompt)

        XCTAssertEqual(
            converted.map { $0.parts.reduce("") { $0 + ($1.text ?? "") } },
            expected.map(\.content)
        )
        XCTAssertEqual(
            converted.map(\.role),
            expected.map(\.role).map(ModelContent.convertRole(_:))
        )
    }

    func test_non_top_system_prompt_should_merge_as_user_prompt() {
        let prompt: [ChatCompletionsRequestBody.Message] = [
            .init(role: .user, content: "A"),
            .init(role: .system, content: "SystemPrompt"),
            .init(role: .assistant, content: "B"),
            .init(role: .user, content: "Hello"),
        ]

        let expected: [ChatCompletionsRequestBody.Message] = [
            .init(role: .user, content: """
            A

            ======

            System Prompt:
            SystemPrompt
            """),
            .init(role: .assistant, content: "B"),
            .init(role: .user, content: "Hello"),
        ]

        let converted = convert(prompt)

        XCTAssertEqual(
            converted.map { $0.parts.reduce("") { $0 + ($1.text ?? "") } },
            expected.map(\.content)
        )
        XCTAssertEqual(
            converted.map(\.role),
            expected.map(\.role).map(ModelContent.convertRole(_:))
        )
    }

    func test_function_call_should_convert_assistant_and_user_message_with_text_content() {
        let prompt: [ChatCompletionsRequestBody.Message] = [
            .init(role: .user, content: "A"),
            .init(
                role: .assistant,
                content: "",
                toolCalls: [
                    .init(
                        id: "id",
                        type: "function",
                        function: .init(name: "ping", arguments: "{ \"ip\": \"127.0.0.1\" }")
                    ),
                ]
            ),
            .init(role: .tool, content: "42ms", toolCallId: "id"),
            .init(role: .assistant, content: "Merge me"),
            .init(role: .user, content: "Merge me"),
            .init(role: .user, content: "Merge me"),
            .init(role: .assistant, content: "B"),
            .init(role: .user, content: "Hello"),
        ]

        let expected: [ChatCompletionsRequestBody.Message] = [
            .init(role: .user, content: "A"),
            .init(role: .assistant, content: """
            Function ID: id
            Call function: ping
            Arguments: { "ip": "127.0.0.1" }
            """),
            .init(role: .user, content: """
            Result of function ID: id
            42ms
            """),
            .init(role: .assistant, content: "Merge me"),
            .init(role: .user, content: """
            Merge me

            ======

            Merge me
            """),
            .init(role: .assistant, content: "B"),
            .init(role: .user, content: "Hello"),
        ]

        let converted = convert(prompt)

        XCTAssertEqual(
            converted.map { $0.parts.reduce("") { $0 + ($1.text ?? "") } },
            expected.map(\.content)
        )
        XCTAssertEqual(
            converted.map(\.role),
            expected.map(\.role).map(ModelContent.convertRole(_:))
        )
    }

    func test_if_the_second_last_message_is_from_user_add_a_dummy() {
        let prompt: [ChatCompletionsRequestBody.Message] = [
            .init(role: .user, content: "A"),
            .init(role: .user, content: "Hello"),
        ]

        let expected: [ChatCompletionsRequestBody.Message] = [
            .init(role: .user, content: "A"),
            .init(role: .assistant, content: "OK"),
            .init(role: .user, content: "Hello"),
        ]

        let converted = convert(prompt)

        XCTAssertEqual(
            converted.map { $0.parts.reduce("") { $0 + ($1.text ?? "") } },
            expected.map(\.content)
        )
        XCTAssertEqual(
            converted.map(\.role),
            expected.map(\.role).map(ModelContent.convertRole(_:))
        )
    }
}

