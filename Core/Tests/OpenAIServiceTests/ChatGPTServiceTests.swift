import XCTest
@testable import OpenAIService

struct MockCompletionStreamAPI_Success: CompletionStreamAPI {
    func callAsFunction() async throws -> (
        trunkStream: AsyncThrowingStream<CompletionStreamDataTrunk, Error>,
        cancel: OpenAIService.Cancellable
    ) {
        return (
            AsyncThrowingStream<CompletionStreamDataTrunk, Error> { continuation in
                let trunks: [CompletionStreamDataTrunk] = [
                    .init(id: "1", object: "", created: 0, model: "", choices: [
                        .init(delta: .init(role: .assistant), index: 0, finish_reason: ""),
                    ]),
                    .init(id: "1", object: "", created: 0, model: "", choices: [
                        .init(delta: .init(content: "hello"), index: 0, finish_reason: ""),
                    ]),
                    .init(id: "1", object: "", created: 0, model: "", choices: [
                        .init(delta: .init(content: "my"), index: 0, finish_reason: ""),
                    ]),
                    .init(id: "1", object: "", created: 0, model: "", choices: [
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

final class ChatGPTServiceTests: XCTestCase {
    func test_success() async throws {
        let service = ChatGPTService(systemPrompt: "system", apiKey: "Key")
        var apiKey = ""
        var idCounter = 0
        await service.changeUUIDGenerator {
            defer { idCounter += 1 }
            return "\(idCounter)"
        }
        var requestBody: CompletionRequestBody?
        await service.changeBuildCompletionStreamAPI { _apiKey, _, _requestBody in
            apiKey = _apiKey
            requestBody = _requestBody
            return MockCompletionStreamAPI_Success()
        }
        let stream = try await service.send(content: "Hello")
        var all = [String]()
        for try await text in stream {
            all.append(text)
            let history = await service.history
            XCTAssertEqual(history.last?.id, "1")
            XCTAssertTrue(
                history.last?.content.hasPrefix(all.joined()) ?? false,
                "History is dynamically updated"
            )
        }

        XCTAssertEqual(apiKey, "Key")
        XCTAssertEqual(requestBody?.messages, [
            .init(role: .system, content: "system"),
            .init(role: .user, content: "Hello"),
        ], "System prompt is included")
        XCTAssertEqual(all, ["hello", "my", "friends"], "Text stream is correct")
        let history = await service.history
        XCTAssertEqual(history, [
            .init(id: "0", role: .user, content: "Hello"),
            .init(id: "1", role: .assistant, content: "hellomyfriends"),
        ], "History is correctly updated")
    }
}
