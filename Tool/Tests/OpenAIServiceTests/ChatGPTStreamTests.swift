import XCTest
@testable import OpenAIService

final class ChatGPTStreamTests: XCTestCase {
    func test_sending_message() async throws {
        let memory = ConversationChatGPTMemory(systemPrompt: "system", systemMessageId: "s")
        let configuration = UserPreferenceChatGPTConfiguration().overriding()
        let functionProvider = NoChatGPTFunctionProvider()
        let service = ChatGPTService(
            memory: memory,
            configuration: configuration,
            functionProvider: functionProvider
        )
        var requestBody: CompletionRequestBody?
        var idCounter = 0
        service.changeUUIDGenerator {
            defer { idCounter += 1 }
            return "\(idCounter)"
        }
        service.changeBuildCompletionStreamAPI { _, _, _, _requestBody in
            requestBody = _requestBody
            return MockCompletionStreamAPI_Message(genId: {
                defer { idCounter += 1 }
                return "\(idCounter)"
            })
        }

        let stream = try await service.send(content: "Hello")
        var all = [String]()
        for try await text in stream {
            all.append(text)
            let history = await memory.messages
            XCTAssertEqual(history.last?.id, "1")
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

        var history = await memory.messages
        for (i, _) in history.enumerated() {
            history[i].tokensCount = nil
        }
        XCTAssertEqual(history, [
            .init(id: "s", role: .system, content: "system"),
            .init(id: "0", role: .user, content: "Hello"),
            .init(id: "1", role: .assistant, content: "hellomyfriends"),
        ], "History is not updated")

        XCTAssertEqual(requestBody?.functions, nil, "Function schema is not submitted")
    }

    func test_handling_function_call() async throws {
        let memory = ConversationChatGPTMemory(systemPrompt: "system", systemMessageId: "s")
        let configuration = UserPreferenceChatGPTConfiguration().overriding()
        let functionProvider = FunctionProvider()
        let service = ChatGPTService(
            memory: memory,
            configuration: configuration,
            functionProvider: functionProvider
        )
        var requestBody: CompletionRequestBody?
        var idCounter = 0
        service.changeUUIDGenerator {
            defer { idCounter += 1 }
            return "\(idCounter)"
        }
        service.changeBuildCompletionStreamAPI { _, _, _, _requestBody in
            requestBody = _requestBody
            if _requestBody.messages.count <= 2 {
                return MockCompletionStreamAPI_Function(genId: {
                    defer { idCounter += 1 }
                    return "\(idCounter)"
                })
            }
            return MockCompletionStreamAPI_Message(genId: {
                defer { idCounter += 1 }
                return "\(idCounter)"
            })
        }

        let stream = try await service.send(content: "Hello")
        var all = [String]()
        for try await text in stream {
            all.append(text)
            let history = await memory.messages
            XCTAssertEqual(history.last?.id, "3")
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
                function_call: .init(name: "function", arguments: "{\n\"foo\": 1\n}")
            ),
            .init(role: .function, content: "Function is called.", name: "function"),
        ], "System prompt is not included")

        XCTAssertEqual(all, ["hello", "my", "friends"], "Text stream is not correct")

        var history = await memory.messages
        for (i, _) in history.enumerated() {
            history[i].tokensCount = nil
        }
        XCTAssertEqual(history, [
            .init(id: "s", role: .system, content: "system"),
            .init(id: "0", role: .user, content: "Hello"),
            .init(
                id: "1",
                role: .assistant,
                content: nil,
                functionCall: .init(name: "function", arguments: "{\n\"foo\": 1\n}")
            ),
            .init(
                id: "2",
                role: .function,
                content: "Function is called.",
                name: "function",
                summary: nil
            ),
            .init(id: "3", role: .assistant, content: "hellomyfriends"),
        ], "History is not updated")

        XCTAssertEqual(requestBody?.functions, [
            EmptyFunction(),
        ].map {
            .init(name: $0.name, description: $0.description, parameters: $0.argumentSchema)
        }, "Function schema is not submitted")
    }

    func test_handling_multiple_function_call() async throws {
        let memory = ConversationChatGPTMemory(systemPrompt: "system", systemMessageId: "s")
        let configuration = UserPreferenceChatGPTConfiguration().overriding()
        let functionProvider = FunctionProvider()
        let service = ChatGPTService(
            memory: memory,
            configuration: configuration,
            functionProvider: functionProvider
        )
        var requestBody: CompletionRequestBody?
        var idCounter = 0
        service.changeUUIDGenerator {
            defer { idCounter += 1 }
            return "\(idCounter)"
        }
        service.changeBuildCompletionStreamAPI { _, _, _, _requestBody in
            requestBody = _requestBody
            if _requestBody.messages.count <= 4 {
                return MockCompletionStreamAPI_Function(genId: {
                    defer { idCounter += 1 }
                    return "\(idCounter)"
                })
            }
            return MockCompletionStreamAPI_Message(genId: {
                defer { idCounter += 1 }
                return "\(idCounter)"
            })
        }

        let stream = try await service.send(content: "Hello")
        var all = [String]()
        for try await text in stream {
            all.append(text)
            let history = await memory.messages
            XCTAssertEqual(history.last?.id, "5")
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
                function_call: .init(name: "function", arguments: "{\n\"foo\": 1\n}")
            ),
            .init(role: .function, content: "Function is called.", name: "function"),
            .init(
                role: .assistant, content: "",
                function_call: .init(name: "function", arguments: "{\n\"foo\": 1\n}")
            ),
            .init(role: .function, content: "Function is called.", name: "function"),
        ], "System prompt is not included")

        XCTAssertEqual(all, ["hello", "my", "friends"], "Text stream is not correct")

        var history = await memory.messages
        for (i, _) in history.enumerated() {
            history[i].tokensCount = nil
        }
        XCTAssertEqual(history, [
            .init(id: "s", role: .system, content: "system"),
            .init(id: "0", role: .user, content: "Hello"),
            .init(
                id: "1",
                role: .assistant,
                content: nil,
                functionCall: .init(name: "function", arguments: "{\n\"foo\": 1\n}")
            ),
            .init(
                id: "2",
                role: .function,
                content: "Function is called.",
                name: "function",
                summary: nil
            ),
            .init(
                id: "3",
                role: .assistant,
                content: nil,
                functionCall: .init(name: "function", arguments: "{\n\"foo\": 1\n}")
            ),
            .init(
                id: "4",
                role: .function,
                content: "Function is called.",
                name: "function",
                summary: nil
            ),
            .init(id: "5", role: .assistant, content: "hellomyfriends"),
        ], "History is not updated")

        XCTAssertEqual(requestBody?.functions, [
            EmptyFunction(),
        ].map {
            .init(name: $0.name, description: $0.description, parameters: $0.argumentSchema)
        }, "Function schema is not submitted")
    }
}

extension ChatGPTStreamTests {
    struct MockCompletionStreamAPI_Message: CompletionStreamAPI {
        var genId: () -> String
        func callAsFunction() async throws -> (
            trunkStream: AsyncThrowingStream<CompletionStreamDataTrunk, Error>,
            cancel: OpenAIService.Cancellable
        ) {
            let id = genId()
            return (
                AsyncThrowingStream<CompletionStreamDataTrunk, Error> { continuation in
                    let trunks: [CompletionStreamDataTrunk] = [
                        .init(id: id, object: "", model: "", choices: [
                            .init(delta: .init(role: .assistant), index: 0, finish_reason: ""),
                        ]),
                        .init(id: id, object: "", model: "", choices: [
                            .init(delta: .init(content: "hello"), index: 0, finish_reason: ""),
                        ]),
                        .init(id: id, object: "", model: "", choices: [
                            .init(delta: .init(content: "my"), index: 0, finish_reason: ""),
                        ]),
                        .init(id: id, object: "", model: "", choices: [
                            .init(delta: .init(content: "friends"), index: 0, finish_reason: ""),
                        ]),
                    ]
                    for trunk in trunks {
                        continuation.yield(trunk)
                    }
                    continuation.finish()
                },
                Cancellable(cancel: {})
            )
        }
    }

    struct MockCompletionStreamAPI_Function: CompletionStreamAPI {
        var genId: () -> String
        func callAsFunction() async throws -> (
            trunkStream: AsyncThrowingStream<CompletionStreamDataTrunk, Error>,
            cancel: OpenAIService.Cancellable
        ) {
            let id = genId()
            return (
                AsyncThrowingStream<CompletionStreamDataTrunk, Error> { continuation in
                    let trunks: [CompletionStreamDataTrunk] = [
                        .init(id: id, object: "", model: "", choices: [
                            .init(
                                delta: .init(
                                    role: .assistant,
                                    function_call: .init(name: "function", arguments: "")
                                ),
                                index: 0,
                                finish_reason: ""
                            )]),
                        .init(id: id, object: "", model: "", choices: [
                            .init(
                                delta: .init(
                                    role: .assistant,
                                    function_call: .init(arguments: "{\n")
                                ),
                                index: 0,
                                finish_reason: ""
                            )]),
                        .init(id: id, object: "", model: "", choices: [
                            .init(
                                delta: .init(
                                    role: .assistant,
                                    function_call: .init(arguments: "\"foo\": 1")
                                ),
                                index: 0,
                                finish_reason: ""
                            )]),
                        .init(id: id, object: "", model: "", choices: [
                            .init(
                                delta: .init(
                                    role: .assistant,
                                    function_call: .init(arguments: "\n}")
                                ),
                                index: 0,
                                finish_reason: ""
                            )]),
                    ]
                    for trunk in trunks {
                        continuation.yield(trunk)
                    }
                    continuation.finish()
                },
                Cancellable(cancel: {})
            )
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

