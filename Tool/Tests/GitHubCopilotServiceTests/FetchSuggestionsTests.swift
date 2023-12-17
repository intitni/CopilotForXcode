import LanguageServerProtocol
import XCTest

@testable import GitHubCopilotService

final class FetchSuggestionTests: XCTestCase {
    func test_process_suggestions_from_server() async throws {
        struct TestServer: GitHubCopilotLSP {
            func sendNotification(_ notif: LanguageServerProtocol.ClientNotification) async throws {
                fatalError()
            }
            
            func sendRequest<E>(_: E) async throws -> E.Response where E: GitHubCopilotRequestType {
                return GitHubCopilotRequest.GetCompletionsCycling.Response(completions: [
                    .init(
                        id: "uuid",
                        text: "Hello World\n",
                        position: .init((0, 0)),
                        range: .init(start: .init((0, 0)), end: .init((0, 4)))
                    ),
                    .init(
                        id: "uuid",
                        text: " ",
                        position: .init((0, 0)),
                        range: .init(start: .init((0, 0)), end: .init((0, 1)))
                    ),
                    .init(
                        id: "uuid",
                        text: " \n",
                        position: .init((0, 0)),
                        range: .init(start: .init((0, 0)), end: .init((0, 2)))
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
            usesTabsForIndentation: false,
            ignoreSpaceOnlySuggestions: false,
            ignoreTrailingNewLinesAndSpaces: false
        )
        XCTAssertEqual(completions.count, 3)
    }

    func test_ignore_empty_suggestions() async throws {
        struct TestServer: GitHubCopilotLSP {
            func sendNotification(_ notif: LanguageServerProtocol.ClientNotification) async throws {
                fatalError()
            }
            
            func sendRequest<E>(_: E) async throws -> E.Response where E: GitHubCopilotRequestType {
                return GitHubCopilotRequest.GetCompletionsCycling.Response(completions: [
                    .init(
                        id: "uuid",
                        text: "Hello World\n",
                        position: .init((0, 0)),
                        range: .init(start: .init((0, 0)), end: .init((0, 4)))
                    ),
                    .init(
                        id: "uuid",
                        text: " ",
                        position: .init((0, 0)),
                        range: .init(start: .init((0, 0)), end: .init((0, 1)))
                    ),
                    .init(
                        id: "uuid",
                        text: " \n",
                        position: .init((0, 0)),
                        range: .init(start: .init((0, 0)), end: .init((0, 2)))
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
            usesTabsForIndentation: false,
            ignoreSpaceOnlySuggestions: true,
            ignoreTrailingNewLinesAndSpaces: false
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

        class TestServer: GitHubCopilotLSP {
            func sendNotification(_ notif: LanguageServerProtocol.ClientNotification) async throws {
                // unimplemented
            }
            
            func sendRequest<E>(_ r: E) async throws -> E.Response where E: GitHubCopilotRequestType {
                return GitHubCopilotRequest.GetCompletionsCycling.Response(completions: [
                    .init(
                        id: "uuid",
                        text: "Hello World\n",
                        position: .init((0, 0)),
                        range: .init(start: .init((0, 0)), end: .init((0, 4)))
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
            usesTabsForIndentation: false,
            ignoreSpaceOnlySuggestions: false,
            ignoreTrailingNewLinesAndSpaces: true
        )
        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(completions.first?.text, "Hello World")
    }
}
