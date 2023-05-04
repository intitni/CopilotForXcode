import LanguageServerProtocol
import XCTest

@testable import GitHubCopilotService

final class FetchSuggestionTests: XCTestCase {
    func test_process_sugestions_from_server() async throws {
        struct TestServer: CopilotLSP {
            func sendRequest<E>(_: E) async throws -> E.Response where E: CopilotRequestType {
                return CopilotRequest.GetCompletionsCycling.Response(completions: [
                    .init(
                        text: "Hello World\n",
                        position: .init((0, 0)),
                        uuid: "uuid",
                        range: .init(start: .init((0, 0)), end: .init((0, 4))),
                        displayText: "Hello"
                    ),
                    .init(
                        text: " ",
                        position: .init((0, 0)),
                        uuid: "uuid",
                        range: .init(start: .init((0, 0)), end: .init((0, 1))),
                        displayText: " "
                    ),
                    .init(
                        text: " \n",
                        position: .init((0, 0)),
                        uuid: "uuid",
                        range: .init(start: .init((0, 0)), end: .init((0, 2))),
                        displayText: " \n"
                    ),
                ]) as! E.Response
            }
        }
        let service = CopilotSuggestionService(designatedServer: TestServer())
        let completions = try await service.getCompletions(
            fileURL: .init(fileURLWithPath: "/file.swift"),
            content: "",
            cursorPosition: .outOfScope,
            tabSize: 4,
            indentSize: 4,
            usesTabsForIndentation: false,
            ignoreSpaceOnlySuggestions: false
        )
        XCTAssertEqual(completions.count, 3)
    }

    func test_ignore_empty_suggestions() async throws {
        struct TestServer: CopilotLSP {
            func sendRequest<E>(_: E) async throws -> E.Response where E: CopilotRequestType {
                return CopilotRequest.GetCompletionsCycling.Response(completions: [
                    .init(
                        text: "Hello World\n",
                        position: .init((0, 0)),
                        uuid: "uuid",
                        range: .init(start: .init((0, 0)), end: .init((0, 4))),
                        displayText: "Hello"
                    ),
                    .init(
                        text: " ",
                        position: .init((0, 0)),
                        uuid: "uuid",
                        range: .init(start: .init((0, 0)), end: .init((0, 1))),
                        displayText: " "
                    ),
                    .init(
                        text: " \n",
                        position: .init((0, 0)),
                        uuid: "uuid",
                        range: .init(start: .init((0, 0)), end: .init((0, 2))),
                        displayText: " \n"
                    ),
                ]) as! E.Response
            }
        }
        let service = CopilotSuggestionService(designatedServer: TestServer())
        let completions = try await service.getCompletions(
            fileURL: .init(fileURLWithPath: "/file.swift"),
            content: "",
            cursorPosition: .outOfScope,
            tabSize: 4,
            indentSize: 4,
            usesTabsForIndentation: false,
            ignoreSpaceOnlySuggestions: true
        )
        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(completions.first?.text, "Hello World\n")
    }

    func test_if_language_identifier_is_unknown_returns_correctly() async throws {
        struct Err: Error, LocalizedError {
            var errorDescription: String? {
                "sendRequest Should not be falled"
            }
        }

        class TestServer: CopilotLSP {
            func sendRequest<E>(_ r: E) async throws -> E.Response where E: CopilotRequestType {
                return CopilotRequest.GetCompletionsCycling.Response(completions: [
                    .init(
                        text: "Hello World\n",
                        position: .init((0, 0)),
                        uuid: "uuid",
                        range: .init(start: .init((0, 0)), end: .init((0, 4))),
                        displayText: "Hello"
                    ),
                ]) as! E.Response
            }
        }
        let testServer = TestServer()
        let service = CopilotSuggestionService(designatedServer: testServer)
        let completions = try await service.getCompletions(
            fileURL: .init(fileURLWithPath: "/"),
            content: "",
            cursorPosition: .outOfScope,
            tabSize: 4,
            indentSize: 4,
            usesTabsForIndentation: false,
            ignoreSpaceOnlySuggestions: false
        )
        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(completions.first?.text, "Hello World\n")
    }
}
