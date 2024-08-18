import AIModel
import ChatBasic
import Dependencies
import Foundation
import XCTest

@testable import OpenAIService

class ChatGPTServiceTests: XCTestCase {
    func test_send_memory_and_handles_responses_with_chunks() async throws {
        let api = ChunksChatCompletionsStreamAPI(chunks: [
            .token("hello"),
            .token(" "),
            .token("world"),
            .token("!"),
            .finish(reason: "finished"),
        ])
        let builder = APIBuilder(api: api)
        let memory = EmptyChatGPTMemory()
        let stream = withDependencies { values in
            values.uuid = .incrementing
            values.date = .constant(Date())
            values.chatCompletionsAPIBuilder = builder
        } operation: {
            let service = ChatGPTService(
                configuration: EmptyConfiguration(),
                functionProvider: NoChatGPTFunctionProvider()
            )
            return service.send(memory)
        }

        let response = try await stream.asArray()
        XCTAssertEqual(response, [
            .partialText("hello"),
            .partialText(" "),
            .partialText("world"),
            .partialText("!"),
        ])

        let history = await memory.history
        XCTAssertEqual(history, [
            .init(
                id: "00000000-0000-0000-0000-000000000000",
                role: .assistant,
                content: "hello world!"
            ),
        ])
    }

    func test_send_memory_returns_tool_calls() async throws {
        let api = ChunksChatCompletionsStreamAPI(
            chunks: [
                .partialToolCalls([
                    .init(index: 0, id: "1", type: "function", function: .init(name: "foo")),
                    .init(index: 1, id: "2", type: "function", function: .init(name: "bar")),
                ]),
                .partialToolCalls([
                    .init(
                        index: 0,
                        id: "1",
                        type: "function",
                        function: .init(arguments: "{\"foo\": \"hi\"}")
                    ),
                    .init(
                        index: 1,
                        id: "2",
                        type: "function",
                        function: .init(arguments: "{\"bar\": \"bye\"}")
                    ),
                ]),
            ]
        )
        let builder = APIBuilder(api: api)
        let memory = EmptyChatGPTMemory()
        let stream = withDependencies { values in
            values.uuid = .incrementing
            values.date = .constant(Date())
            values.chatCompletionsAPIBuilder = builder
        } operation: {
            let service = ChatGPTService(
                configuration: EmptyConfiguration(),
                functionProvider: FunctionProvider()
            )
            return service.send(memory)
        }

        let response = try await stream.asArray()
        XCTAssertEqual(response, [
            .toolCalls([
                .init(
                    id: "1",
                    type: "function",
                    function: .init(name: "foo", arguments: "{\"foo\": \"hi\"}"),
                    response: nil
                ),
                .init(
                    id: "2",
                    type: "function",
                    function: .init(name: "bar", arguments: "{\"bar\": \"bye\"}"),
                    response: nil
                ),
            ]),
        ])

        let history = await memory.history
        XCTAssertEqual(history, [
            .init(
                id: "00000000-0000-0000-0000-000000000000",
                role: .assistant,
                content: nil,
                toolCalls: [
                    .init(
                        id: "1",
                        type: "function",
                        function: .init(name: "foo", arguments: "{\"foo\": \"hi\"}"),
                        response: nil
                    ),
                    .init(
                        id: "2",
                        type: "function",
                        function: .init(name: "bar", arguments: "{\"bar\": \"bye\"}"),
                        response: nil
                    ),
                ]
            ),
        ])
    }

    func test_send_memory_and_automatically_handles_multiple_tool_calls() async throws {
        let api = ChunksChatCompletionsStreamAPI(chunks: [[
                .partialToolCalls([
                    .init(index: 0, id: "1", type: "function", function: .init(name: "foo")),
                    .init(index: 1, id: "2", type: "function", function: .init(name: "bar")),
                ]),
                .partialToolCalls([
                    .init(
                        index: 0,
                        id: "1",
                        type: "function",
                        function: .init(arguments: "{\"foo\": \"hi\"}")
                    ),
                    .init(
                        index: 1,
                        id: "2",
                        type: "function",
                        function: .init(arguments: "{\"bar\": \"bye\"}")
                    ),
                ]),
            ],
            [
                .token("hello"),
                .token(" "),
                .token("world"),
                .token("!"),
                .finish(reason: "finished"),
            ],
            ])
        let builder = APIBuilder(api: api)
        let memory = EmptyChatGPTMemory()
        let stream = withDependencies { values in
            values.uuid = .incrementing
            values.date = .constant(Date())
            values.chatCompletionsAPIBuilder = builder
        } operation: {
            let service = ChatGPTService(
                configuration: EmptyConfiguration().overriding {
                    $0.runFunctionsAutomatically = true
                },
                functionProvider: FunctionProvider()
            )
            return service.send(memory)
        }

        let response = try await stream.asArray()
        XCTAssertEqual(response, [
            .status("start foo 1"),
            .status("start foo 2"),
            .status("start foo 3"),
            .status("start bar 1"),
            .status("start bar 2"),
            .status("start bar 3"),
            .status("foo hi"),
            .status("bar bye"),
            .partialText("hello"),
            .partialText(" "),
            .partialText("world"),
            .partialText("!"),
        ])

        let history = await memory.history
        XCTAssertEqual(history, [
            .init(
                id: "00000000-0000-0000-0000-000000000000",
                role: .assistant,
                content: nil,
                toolCalls: [
                    .init(
                        id: "1",
                        type: "function",
                        function: .init(name: "foo", arguments: "{\"foo\": \"hi\"}"),
                        response: .init(content: "foo hi", summary: "foo hi")
                    ),
                    .init(
                        id: "2",
                        type: "function",
                        function: .init(name: "bar", arguments: "{\"bar\": \"bye\"}"),
                        response: .init(content: "Error: bar error", summary: "Error: bar error")
                    ),
                ]
            ),
            .init(
                id: "00000000-0000-0000-0000-000000000001",
                role: .assistant,
                content: "hello world!"
            ),
        ])
    }

    func test_send_memory_and_automatically_handles_unknown_tool_call() async throws {
        let api = ChunksChatCompletionsStreamAPI(chunks: [[
                .partialToolCalls([
                    .init(index: 0, id: "1", type: "function", function: .init(name: "python")),
                    .init(index: 1, id: "2", type: "function", function: .init(name: "unknown")),
                ]),
                .partialToolCalls([
                    .init(
                        index: 0,
                        id: "1",
                        type: "function",
                        function: .init(arguments: "{\"foo\": \"hi\"}")
                    ),
                    .init(
                        index: 1,
                        id: "2",
                        type: "function",
                        function: .init(arguments: "{\"foo\": \"hi\"}")
                    ),
                ]),
            ],
            [
                .token("result a"),
            ],
            [
                .token("result b"),
            ],
            [
                .token("hello"),
                .token(" "),
                .token("world"),
                .token("!"),
                .finish(reason: "finished"),
            ],
            ])
        let builder = APIBuilder(api: api)
        let memory = EmptyChatGPTMemory()
        let stream = withDependencies { values in
            values.uuid = .incrementing
            values.date = .constant(Date())
            values.chatCompletionsAPIBuilder = builder
        } operation: {
            let service = ChatGPTService(
                configuration: EmptyConfiguration().overriding {
                    $0.runFunctionsAutomatically = true
                },
                functionProvider: FunctionProvider()
            )
            return service.send(memory)
        }

        let response = try await stream.asArray()
        XCTAssertEqual(response, [
            .partialText("hello"),
            .partialText(" "),
            .partialText("world"),
            .partialText("!"),
        ])

        let history = await memory.history
        XCTAssertEqual(history, [
            .init(
                id: "00000000-0000-0000-0000-000000000000",
                role: .assistant,
                content: nil,
                toolCalls: [
                    .init(
                        id: "1",
                        type: "function",
                        function: .init(name: "python", arguments: "{\"foo\": \"hi\"}"),
                        response: .init(content: "result a", summary: "Finished running function.")
                    ),
                    .init(
                        id: "2",
                        type: "function",
                        function: .init(name: "unknown", arguments: "{\"foo\": \"hi\"}"),
                        response: .init(content: "result b", summary: "Finished running function.")
                    ),
                ]
            ),
            .init(
                id: "00000000-0000-0000-0000-000000000003",
                role: .assistant,
                content: "hello world!"
            ),
        ])
    }
    
    func test_send_memory_and_handles_error() async throws {
        struct E: Error, LocalizedError {
            var errorDescription: String? { "error happens" }
        }
        let api = ChunksChatCompletionsStreamAPI(chunks: [
            .token("hello"),
            .token(" "),
            .failure(E())
        ])
        let builder = APIBuilder(api: api)
        let memory = EmptyChatGPTMemory()
        let stream = withDependencies { values in
            values.uuid = .incrementing
            values.date = .constant(Date())
            values.chatCompletionsAPIBuilder = builder
        } operation: {
            let service = ChatGPTService(
                configuration: EmptyConfiguration(),
                functionProvider: NoChatGPTFunctionProvider()
            )
            return service.send(memory)
        }

        var results = [ChatGPTResponse]()
        let expectError = expectation(description: "error")
        do {
            for try await item in stream {
                results.append(item)
            }
        } catch is E {
            expectError.fulfill()
        } catch {
            XCTFail("Incorrect Error")
        }

        await fulfillment(of: [expectError], timeout: 1)
        let history = await memory.history
        XCTAssertEqual(history, [
            .init(
                id: "00000000-0000-0000-0000-000000000000",
                role: .assistant,
                content: "hello "
            ),
            .init(
                id: "00000000-0000-0000-0000-000000000001",
                role: .assistant,
                content: "error happens"
            ),
        ])
    }
    
    func test_send_memory_and_handles_cancellation() async throws {
        let api = ChunksChatCompletionsStreamAPI(chunks: [
            .token("hello"),
            .token(" "),
            .failure(CancellationError())
        ])
        let builder = APIBuilder(api: api)
        let memory = EmptyChatGPTMemory()
        let stream = withDependencies { values in
            values.uuid = .incrementing
            values.date = .constant(Date())
            values.chatCompletionsAPIBuilder = builder
        } operation: {
            let service = ChatGPTService(
                configuration: EmptyConfiguration(),
                functionProvider: NoChatGPTFunctionProvider()
            )
            return service.send(memory)
        }

        var results = [ChatGPTResponse]()
        let expectError = expectation(description: "error")
        do {
            for try await item in stream {
                results.append(item)
            }
        } catch is CancellationError {
            expectError.fulfill()
        } catch {
            XCTFail("Incorrect Error")
        }

        await fulfillment(of: [expectError], timeout: 1)
        let history = await memory.history
        XCTAssertEqual(history, [
            .init(
                id: "00000000-0000-0000-0000-000000000000",
                role: .assistant,
                content: "hello "
            ),
        ])
    }
}

private struct APIBuilder: ChatCompletionsAPIBuilder {
    let api: ChatCompletionsStreamAPI

    func buildStreamAPI(
        model: ChatModel,
        endpoint: URL,
        apiKey: String,
        requestBody: ChatCompletionsRequestBody
    ) -> any ChatCompletionsStreamAPI {
        api
    }

    func buildNonStreamAPI(
        model: ChatModel,
        endpoint: URL,
        apiKey: String,
        requestBody: ChatCompletionsRequestBody
    ) -> any ChatCompletionsAPI {
        fatalError()
    }
}

private struct EmptyConfiguration: ChatGPTConfiguration {
    var model: AIModel.ChatModel? { .init(id: "", name: "", format: .openAI, info: .init()) }
    var temperature: Double { 0 }
    var stop: [String] { [] }
    var maxTokens: Int { 99999 }
    var minimumReplyTokens: Int { 99999 }
    var runFunctionsAutomatically: Bool { false }
    var shouldEndTextWindow: (String) -> Bool = { _ in true }
}

private class ChunksChatCompletionsStreamAPI: ChatCompletionsStreamAPI {
    private(set) var chunks: [[Result<ChatCompletionsStreamDataChunk, Error>]]
    init(chunks: [Result<ChatCompletionsStreamDataChunk, Error>]) {
        self.chunks = [chunks]
    }

    init(chunks: [[Result<ChatCompletionsStreamDataChunk, Error>]]) {
        self.chunks = chunks
    }

    func callAsFunction() async throws
        -> AsyncThrowingStream<ChatCompletionsStreamDataChunk, Error>
    {
        let chunks = self.chunks.removeFirst()
        return .init {
            for chunk in chunks {
                switch chunk {
                case let .success(chunk):
                    $0.yield(chunk)
                case let .failure(error):
                    $0.finish(throwing: error)
                    return
                }
            }
            $0.finish()
        }
    }
}

private struct ThrowingChatCompletionsStreamAPI: ChatCompletionsStreamAPI {
    let error: any Error
    func callAsFunction() async throws
        -> AsyncThrowingStream<ChatCompletionsStreamDataChunk, Error>
    {
        throw error
    }
}

private extension Result<ChatCompletionsStreamDataChunk, Error> {
    static func token(_ string: String) -> Result<ChatCompletionsStreamDataChunk, Error> {
        .success(.init(
            id: "1",
            object: "object",
            model: "model",
            message: .some(.init(role: .assistant, content: string)),
            finishReason: nil
        ))
    }

    static func partialToolCalls(_ toolCalls: [ChatCompletionsStreamDataChunk.Delta.ToolCall])
        -> Result<ChatCompletionsStreamDataChunk, Error>
    {
        .success(.init(
            id: "1",
            object: "object",
            model: "model",
            message: .some(.init(
                role: .assistant,
                content: nil,
                toolCalls: toolCalls
            )),
            finishReason: nil
        ))
    }

    static func finish(reason: String) -> Result<ChatCompletionsStreamDataChunk, Error> {
        .success(.init(
            id: "1",
            object: "object",
            model: "model",
            message: .some(.init(role: .assistant, content: nil)),
            finishReason: reason
        ))
    }
}

private struct FunctionProvider: ChatGPTFunctionProvider {
    struct Foo: ChatGPTFunction {
        struct Arguments: Codable {
            var foo: String
        }

        struct Result: ChatGPTFunctionResult {
            var result: String
            var botReadableContent: String { result }
        }

        var name: String { "foo" }

        var description: String { "foo" }

        var argumentSchema: ChatBasic.JSONSchemaValue = .string("")

        func prepare(reportProgress: @escaping ReportProgress) async {
            await reportProgress("start foo 1")
            await reportProgress("start foo 2")
            await reportProgress("start foo 3")
        }

        func call(
            arguments: Arguments,
            reportProgress: @escaping ReportProgress
        ) async throws -> Result {
            await reportProgress("foo \(arguments.foo)")
            return .init(result: "foo \(arguments.foo)")
        }
    }

    struct Bar: ChatGPTFunction {
        struct Arguments: Codable {
            var bar: String
        }

        struct Result: ChatGPTFunctionResult {
            var result: String
            var botReadableContent: String { result }
        }

        var name: String { "bar" }

        var description: String { "bar" }

        var argumentSchema: ChatBasic.JSONSchemaValue = .string("")

        func prepare(reportProgress: @escaping ReportProgress) async {
            await reportProgress("start bar 1")
            await reportProgress("start bar 2")
            await reportProgress("start bar 3")
        }

        func call(
            arguments: Arguments,
            reportProgress: @escaping ReportProgress
        ) async throws -> Result {
            await reportProgress("bar \(arguments.bar)")
            struct E: Error, LocalizedError {
                var errorDescription: String? { "bar error" }
            }
            throw E()
        }
    }

    var functions: [any ChatGPTFunction] = [Foo(), Bar()]

    var functionCallStrategy: OpenAIService.FunctionCallStrategy? { nil }
}

