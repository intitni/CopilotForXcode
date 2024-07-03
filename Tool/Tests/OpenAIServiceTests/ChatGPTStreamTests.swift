import ChatBasic
import Dependencies
import XCTest
@testable import OpenAIService

final class ChatGPTStreamTests: XCTestCase {
    func test_sending_message() async throws {
        let memory = ConversationChatGPTMemory(systemPrompt: "system", systemMessageId: "s")
        let configuration = UserPreferenceChatGPTConfiguration().overriding {
            $0.model = .init(id: "id", name: "name", format: .openAI, info: .init())
        }
        let functionProvider = NoChatGPTFunctionProvider()
        let service = ChatGPTService(
            memory: memory,
            configuration: configuration,
            functionProvider: functionProvider
        )
        var requestBody: ChatCompletionsRequestBody?
        service.changeBuildCompletionStreamAPI { _, _, _, _requestBody, _ in
            requestBody = _requestBody
            return MockCompletionStreamAPI_Message()
        }

        try await withDependencies { values in
            values.uuid = .incrementing
            values.date = .constant(.init(timeIntervalSince1970: 0))
        } operation: {
            let stream = try await service.send(content: "Hello")
            var all = [String]()
            for try await text in stream {
                all.append(text)
                let history = await memory.history
                XCTAssertTrue(
                    history.last?.content?.hasPrefix(all.joined()) ?? false,
                    "History is not updated"
                )
            }

            XCTAssertEqual(requestBody?.messages, [
                .init(role: .system, content: "system"),
                .init(role: .user, content: "Hello"),
            ], "System prompt is not included")

            XCTAssertEqual(all, ["hello", "my", "friends"], "Text stream is not correct")

            var history = await memory.history
            for (i, _) in history.enumerated() {
                history[i].tokensCount = nil
            }
            XCTAssertEqual(history, [
                .init(
                    id: "s",
                    role: .system,
                    content: "system"
                ),
                .init(id: "00000000-0000-0000-0000-000000000000", role: .user, content: "Hello"),
                .init(
                    id: "00000000-0000-0000-0000-0000000000010.0",
                    role: .assistant,
                    content: "hellomyfriends"
                ),
            ], "History is not updated")

            XCTAssertEqual(requestBody?.tools, nil, "Function schema is not submitted")
        }
    }

    func test_handling_function_call() async throws {
        let memory = ConversationChatGPTMemory(systemPrompt: "system", systemMessageId: "s")
        let configuration = UserPreferenceChatGPTConfiguration().overriding {
            $0.model = .init(id: "id", name: "name", format: .openAI, info: .init())
        }
        let functionProvider = FunctionProvider()
        let service = ChatGPTService(
            memory: memory,
            configuration: configuration,
            functionProvider: functionProvider
        )
        var requestBody: ChatCompletionsRequestBody?
        service.changeBuildCompletionStreamAPI { _, _, _, _requestBody, _ in
            requestBody = _requestBody
            if _requestBody.messages.count <= 2 {
                return MockCompletionStreamAPI_Function()
            }
            return MockCompletionStreamAPI_Message()
        }

        try await withDependencies { values in
            values.uuid = .incrementing
            values.date = .constant(.init(timeIntervalSince1970: 0))
        } operation: {
            let stream = try await service.send(content: "Hello")
            var all = [String]()
            for try await text in stream {
                all.append(text)
                let history = await memory.history
                XCTAssertEqual(history.last?.id, "00000000-0000-0000-0000-0000000000030.0")
                XCTAssertTrue(
                    history.last?.content?.hasPrefix(all.joined()) ?? false,
                    "History is not updated"
                )
            }

            XCTAssertEqual(requestBody?.messages, [
                .init(role: .system, content: "system"),
                .init(role: .user, content: "Hello"),
                .init(
                    role: .assistant, content: "",
                    toolCalls: [
                        .init(
                            id: "id",
                            type: "function",
                            function: .init(name: "function", arguments: "{\n\"foo\": 1\n}")
                        )]
                ),
                .init(role: .tool, content: "Function is called.", toolCallId: "id"),
            ], "System prompt is not included")

            XCTAssertEqual(all, ["hello", "my", "friends"], "Text stream is not correct")

            var history = await memory.history
            for (i, _) in history.enumerated() {
                history[i].tokensCount = nil
            }
            XCTAssertEqual(history, [
                .init(id: "s", role: .system, content: "system"),
                .init(id: "00000000-0000-0000-0000-000000000000", role: .user, content: "Hello"),
                .init(
                    id: "00000000-0000-0000-0000-0000000000010.0",
                    role: .assistant,
                    content: nil,
                    toolCalls: [
                        .init(
                            id: "id",
                            type: "function",
                            function: .init(name: "function", arguments: "{\n\"foo\": 1\n}"),
                            response: .init(content: "Function is called.", summary: nil)
                        ),
                    ]
                ),
                .init(
                    id: "00000000-0000-0000-0000-0000000000030.0",
                    role: .assistant,
                    content: "hellomyfriends"
                ),
            ], "History is not updated")

            XCTAssertEqual(requestBody?.tools, [
                EmptyFunction(),
            ].map {
                .init(
                    type: "function",
                    function: .init(
                        name: $0.name,
                        description: $0.description,
                        parameters: $0.argumentSchema
                    )
                )
            }, "Function schema is not submitted")
        }
    }

    func test_handling_multiple_function_call() async throws {
        let memory = ConversationChatGPTMemory(systemPrompt: "system", systemMessageId: "s")
        let configuration = UserPreferenceChatGPTConfiguration().overriding {
            $0.model = .init(id: "id", name: "name", format: .openAI, info: .init())
        }
        let functionProvider = FunctionProvider()
        let service = ChatGPTService(
            memory: memory,
            configuration: configuration,
            functionProvider: functionProvider
        )
        var requestBody: ChatCompletionsRequestBody?

        service.changeBuildCompletionStreamAPI { _, _, _, _requestBody, _ in
            requestBody = _requestBody
            if _requestBody.messages.count <= 4 {
                return MockCompletionStreamAPI_Function(count: 3)
            }
            return MockCompletionStreamAPI_Message()
        }

        try await withDependencies { values in
            values.uuid = .incrementing
            values.date = .constant(.init(timeIntervalSince1970: 0))
        } operation: {
            let stream = try await service.send(content: "Hello")
            var all = [String]()
            for try await text in stream {
                all.append(text)
                let history = await memory.history
                XCTAssertEqual(history.last?.id, "00000000-0000-0000-0000-0000000000030.0")
                XCTAssertTrue(
                    history.last?.content?.hasPrefix(all.joined()) ?? false,
                    "History is not updated"
                )
            }

            XCTAssertEqual(requestBody?.messages, [
                .init(role: .system, content: "system"),
                .init(role: .user, content: "Hello"),
                .init(
                    role: .assistant, content: "",
                    toolCalls: [
                        .init(
                            id: "id",
                            type: "function",
                            function: .init(name: "function", arguments: "{\n\"foo\": 1\n}")
                        ),
                        .init(
                            id: "id2",
                            type: "function",
                            function: .init(name: "function", arguments: "{\n\"foo\": 1\n}")
                        ),
                        .init(
                            id: "id3",
                            type: "function",
                            function: .init(name: "function", arguments: "{\n\"foo\": 1\n}")
                        ),
                    ]
                ),
                .init(
                    role: .tool,
                    content: "Function is called.",
                    toolCallId: "id"
                ),
                .init(
                    role: .tool,
                    content: "Function is called.",
                    toolCallId: "id2"
                ),
                .init(
                    role: .tool,
                    content: "Function is called.",
                    toolCallId: "id3"
                ),
            ], "System prompt is not included")

            XCTAssertEqual(all, ["hello", "my", "friends"], "Text stream is not correct")

            var history = await memory.history
            for (i, _) in history.enumerated() {
                history[i].tokensCount = nil
            }
            XCTAssertEqual(history, [
                .init(id: "s", role: .system, content: "system"),
                .init(id: "00000000-0000-0000-0000-000000000000", role: .user, content: "Hello"),
                .init(
                    id: "00000000-0000-0000-0000-0000000000010.0",
                    role: .assistant,
                    content: nil,
                    toolCalls: [
                        .init(
                            id: "id",
                            type: "function",
                            function: .init(name: "function", arguments: "{\n\"foo\": 1\n}"),
                            response: .init(content: "Function is called.", summary: nil)
                        ),
                        .init(
                            id: "id2",
                            type: "function",
                            function: .init(name: "function", arguments: "{\n\"foo\": 1\n}"),
                            response: .init(content: "Function is called.", summary: nil)
                        ),
                        .init(
                            id: "id3",
                            type: "function",
                            function: .init(name: "function", arguments: "{\n\"foo\": 1\n}"),
                            response: .init(content: "Function is called.", summary: nil)
                        ),
                    ]
                ),
                .init(
                    id: "00000000-0000-0000-0000-0000000000030.0",
                    role: .assistant,
                    content: "hellomyfriends"
                ),
            ], "History is not updated")

            XCTAssertEqual(requestBody?.tools, [
                EmptyFunction(),
            ].map {
                .init(
                    type: "function",
                    function: .init(
                        name: $0.name,
                        description: $0.description,
                        parameters: $0.argumentSchema
                    )
                )
            }, "Function schema is not submitted")
        }
    }

    func test_function_calling_unsupported() async throws {
        let memory = ConversationChatGPTMemory(systemPrompt: "system", systemMessageId: "s")
        let configuration = UserPreferenceChatGPTConfiguration().overriding {
            $0.model = .init(
                id: "id",
                name: "name",
                format: .openAI,
                info: .init(supportsFunctionCalling: false)
            )
        }
        let functionProvider = FunctionProvider()
        let service = ChatGPTService(
            memory: memory,
            configuration: configuration,
            functionProvider: functionProvider
        )
        var requestBody: ChatCompletionsRequestBody?
        service.changeBuildCompletionStreamAPI { _, _, _, _requestBody, _ in
            requestBody = _requestBody
            if _requestBody.messages.count <= 2 {
                return MockCompletionStreamAPI_Function()
            }
            return MockCompletionStreamAPI_Message()
        }

        try await withDependencies { values in
            values.uuid = .incrementing
            values.date = .constant(.init(timeIntervalSince1970: 0))
        } operation: {
            let stream = try await service.send(content: "Hello")
            var all = [String]()
            for try await text in stream {
                all.append(text)
                let history = await memory.history
                XCTAssertEqual(history.last?.id, "00000000-0000-0000-0000-0000000000030.0")
                XCTAssertTrue(
                    history.last?.content?.hasPrefix(all.joined()) ?? false,
                    "History is not updated"
                )
            }

            XCTAssertEqual(requestBody?.messages, [
                .init(role: .system, content: "system"),
                .init(role: .user, content: "Hello"),
                .init(
                    role: .assistant, content: ""
                ),
                .init(role: .user, content: "Function is called."),
            ], "System prompt is not included")

            XCTAssertEqual(all, ["hello", "my", "friends"], "Text stream is not correct")

            var history = await memory.history
            for (i, _) in history.enumerated() {
                history[i].tokensCount = nil
            }
            XCTAssertEqual(history, [
                .init(id: "s", role: .system, content: "system"),
                .init(id: "00000000-0000-0000-0000-000000000000", role: .user, content: "Hello"),
                .init(
                    id: "00000000-0000-0000-0000-0000000000010.0",
                    role: .assistant,
                    content: nil,
                    toolCalls: [
                        .init(
                            id: "id",
                            type: "function",
                            function: .init(name: "function", arguments: "{\n\"foo\": 1\n}"),
                            response: .init(content: "Function is called.", summary: nil)
                        ),
                    ]
                ),
                .init(
                    id: "00000000-0000-0000-0000-0000000000030.0",
                    role: .assistant,
                    content: "hellomyfriends"
                ),
            ], "History is not updated")

            XCTAssertEqual(requestBody?.tools, nil, "Functions should be nil")
        }
    }
}

extension ChatGPTStreamTests {
    struct MockCompletionStreamAPI_Message: ChatCompletionsStreamAPI {
        @Dependency(\.uuid) var uuid
        func callAsFunction() async throws
            -> AsyncThrowingStream<OpenAIService.ChatCompletionsStreamDataChunk, Error>
        {
            let id = uuid().uuidString
            return AsyncThrowingStream<ChatCompletionsStreamDataChunk, Error> { continuation in
                let chunks: [ChatCompletionsStreamDataChunk] = [
                    .init(
                        id: id,
                        object: "",
                        model: "",
                        message: .init(role: .assistant),
                        finishReason: ""
                    ),
                    .init(
                        id: id,
                        object: "",
                        model: "",
                        message: .init(content: "hello"),
                        finishReason: ""
                    ),
                    .init(
                        id: id,
                        object: "",
                        model: "",
                        message: .init(content: "my"),
                        finishReason: ""
                    ),
                    .init(
                        id: id,
                        object: "",
                        model: "",
                        message: .init(content: "friends"),
                        finishReason: ""
                    ),
                ]
                for chunk in chunks {
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }
    }

    struct MockCompletionStreamAPI_Function: ChatCompletionsStreamAPI {
        @Dependency(\.uuid) var uuid
        var count: Int = 1
        func callAsFunction() async throws
            -> AsyncThrowingStream<OpenAIService.ChatCompletionsStreamDataChunk, Error>
        {
            let id = uuid().uuidString
            return AsyncThrowingStream<ChatCompletionsStreamDataChunk, Error> { continuation in
                for i in 0..<max(count, 1) {
                    let callId = i == 0 ? "id" : "id\(i + 1)"
                    let chunks: [ChatCompletionsStreamDataChunk] = [
                        .init(
                            id: id,
                            object: "",
                            model: "",
                            message: .init(
                                role: .assistant,
                                toolCalls: [
                                    .init(
                                        index: i,
                                        id: callId,
                                        type: "function",
                                        function: .init(name: "function", arguments: "")
                                    ),
                                ]
                            ),
                            finishReason: ""
                        ),
                        .init(
                            id: id,
                            object: "",
                            model: "",
                            message: .init(
                                role: .assistant,
                                toolCalls: [
                                    .init(
                                        index: i,
                                        id: callId,
                                        type: "function",
                                        function: .init(arguments: "{\n")
                                    ),
                                ]
                            ),
                            finishReason: ""
                        ),
                        .init(
                            id: id,
                            object: "",
                            model: "",
                            message: .init(
                                role: .assistant,
                                toolCalls: [
                                    .init(
                                        index: i,
                                        id: callId,
                                        type: "function",
                                        function: .init(arguments: "\"foo\": 1")
                                    ),
                                ]
                            ),
                            finishReason: ""
                        ),
                        .init(
                            id: id,
                            object: "",
                            model: "",
                            message: .init(
                                role: .assistant,
                                toolCalls: [
                                    .init(
                                        index: i,
                                        id: callId,
                                        type: "function",
                                        function: .init(arguments: "\n}")
                                    ),
                                ]
                            ),
                            finishReason: ""
                        ),
                    ]
                    for chunk in chunks {
                        continuation.yield(chunk)
                    }
                }
                continuation.finish()
            }
        }
    }

    struct EmptyFunction: ChatGPTFunction {
        struct Parameters: Codable {
            var foo: Int
        }

        var name: String { "function" }

        var description: String { "description" }

        var argumentSchema: JSONSchemaValue {
            [
                .type: ["null"],
            ]
        }

        func prepare(reportProgress: @escaping ReportProgress) async {
            print("Function will be called")
        }

        func call(
            arguments: Parameters,
            reportProgress: @escaping ReportProgress
        ) async throws -> String {
            "Function is called."
        }
    }

    struct FunctionProvider: ChatGPTFunctionProvider {
        var functionCallStrategy: OpenAIService.FunctionCallStrategy? { nil }

        var functions: [any ChatGPTFunction] { [EmptyFunction()] }
    }
}

