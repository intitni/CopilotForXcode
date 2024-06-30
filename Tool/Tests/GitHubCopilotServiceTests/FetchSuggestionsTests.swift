import CopilotForXcodeKit
import LanguageServerProtocol
import XCTest

@testable import GitHubCopilotService

struct TestServiceLocator: ServiceLocatorType {
    let server: GitHubCopilotLSP
    func getService(from workspace: WorkspaceInfo) async -> GitHubCopilotService? {
        .init(designatedServer: server)
    }
}

final class FetchSuggestionTests: XCTestCase {
    func test_process_suggestions_from_server() async throws {
        struct TestServer: GitHubCopilotLSP {
            func sendNotification(_: LanguageServerProtocol.ClientNotification) async throws {
                return
            }

            func sendRequest<E>(_: E, timeout: TimeInterval?) async throws -> E.Response
                where E: GitHubCopilotRequestType
            {
                return GitHubCopilotRequest.InlineCompletion.Response(items: [
                    .init(
                        insertText: "Hello World\n",
                        filterText: nil,
                        range: .init(start: .init((0, 0)), end: .init((0, 4))),
                        command: nil
                    ),
                    .init(
                        insertText: " ",
                        filterText: nil,
                        range: .init(start: .init((0, 0)), end: .init((0, 1))),
                        command: nil
                    ),
                    .init(
                        insertText: " \n",
                        filterText: nil,
                        range: .init(start: .init((0, 0)), end: .init((0, 2))),
                        command: nil
                    ),
                ]) as! E.Response
            }
        }
        let service =
            GitHubCopilotSuggestionService(serviceLocator: TestServiceLocator(server: TestServer()))
        let completions = try await service.getSuggestions(
            .init(
                fileURL: .init(fileURLWithPath: "/file.swift"),
                relativePath: "",
                language: .builtIn(.swift),
                content: "",
                originalContent: "",
                cursorPosition: .outOfScope,
                tabSize: 4,
                indentSize: 4,
                usesTabsForIndentation: false,
                relevantCodeSnippets: []
            ),
            workspace: .init(
                workspaceURL: .init(fileURLWithPath: "/"),
                projectURL: .init(fileURLWithPath: "/file.swift")
            )
        )
        XCTAssertEqual(completions.count, 3)
    }

    func test_if_language_identifier_is_unknown_returns_correctly() async throws {
        class TestServer: GitHubCopilotLSP {
            func sendNotification(_: LanguageServerProtocol.ClientNotification) async throws {
                // unimplemented
            }

            func sendRequest<E>(_: E, timeout: TimeInterval?) async throws -> E.Response
                where E: GitHubCopilotRequestType
            {
                return GitHubCopilotRequest.InlineCompletion.Response(items: [
                    .init(
                        insertText: "Hello World\n",
                        filterText: nil,
                        range: .init(start: .init((0, 0)), end: .init((0, 4))),
                        command: nil
                    ),
                ]) as! E.Response
            }
        }
        let testServer = TestServer()
        let service =
            GitHubCopilotSuggestionService(serviceLocator: TestServiceLocator(server: testServer))
        let completions = try await service.getSuggestions(
            .init(
                fileURL: .init(fileURLWithPath: "/"),
                relativePath: "",
                language: .builtIn(.swift),
                content: "",
                originalContent: "",
                cursorPosition: .outOfScope,
                tabSize: 4,
                indentSize: 4,
                usesTabsForIndentation: false,
                relevantCodeSnippets: []
            ),
            workspace: .init(
                workspaceURL: .init(fileURLWithPath: "/"),
                projectURL: .init(fileURLWithPath: "/file.swift")
            )
        )
        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(completions.first?.text, "Hello World\n")
    }
}

