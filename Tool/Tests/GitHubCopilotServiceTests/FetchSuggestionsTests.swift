import LanguageServerProtocol
import XCTest

@testable import GitHubCopilotService

final class FetchSuggestionTests: XCTestCase {
    func test_process_suggestions_from_server() async throws {
        struct TestServer: GitHubCopilotLSP {
            func sendNotification(_: LanguageServerProtocol.ClientNotification) async throws {
                fatalError()
            }

            func sendRequest<E>(_: E) async throws -> E.Response where E: GitHubCopilotRequestType {
                return GitHubCopilotRequest.GetCompletionsCycling.Response(completions: [
                    .init(
                        text: "Hello World\n",
                        position: .init((0, 0)),
                        uuid: "uuid",
                        range: .init(start: .init((0, 0)), end: .init((0, 4))),
                        displayText: ""
                    ),
                    .init(
                        text: " ",
                        position: .init((0, 0)),
                        uuid: "uuid",
                        range: .init(start: .init((0, 0)), end: .init((0, 1))),
                        displayText: ""
                    ),
                    .init(
                        text: " \n",
                        position: .init((0, 0)),
                        uuid: "uuid",
                        range: .init(start: .init((0, 0)), end: .init((0, 2))),
                        displayText: ""
                    ),
                ]) as! E.Response
            }
        }
        let service = GitHubCopilotSuggestionService(designatedServer: TestServer())
        let completions = try await service.getCompletions(
            fileURL: .init(fileURLWithPath: "/file.swift"),
            content: "",
            cursorPosition: .outOfScope,
            tabSize: 4,
            indentSize: 4,
            usesTabsForIndentation: false
        )
        XCTAssertEqual(completions.count, 3)
    }

    func test_if_language_identifier_is_unknown_returns_correctly() async throws {
        class TestServer: GitHubCopilotLSP {
            func sendNotification(_: LanguageServerProtocol.ClientNotification) async throws {
                // unimplemented
            }

            func sendRequest<E>(_: E) async throws -> E.Response where E: GitHubCopilotRequestType {
                return GitHubCopilotRequest.GetCompletionsCycling.Response(completions: [
                    .init(
                        text: "Hello World\n",
                        position: .init((0, 0)),
                        uuid: "uuid",
                        range: .init(start: .init((0, 0)), end: .init((0, 4))),
                        displayText: ""
                    ),
                ]) as! E.Response
            }
        }
        let testServer = TestServer()
        let service = GitHubCopilotSuggestionService(designatedServer: testServer)
        let completions = try await service.getCompletions(
            fileURL: .init(fileURLWithPath: "/"),
            content: "",
            cursorPosition: .outOfScope,
            tabSize: 4,
            indentSize: 4,
            usesTabsForIndentation: false
        )
        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(completions.first?.text, "Hello World\n")
    }
}

