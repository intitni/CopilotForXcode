import AppKit
import Client
import CopilotModel
import CopilotService
import Foundation
import XCTest
import XPCShared

@testable import Service

@ServiceActor func clearEnvironment() {
    workspaces = [:]

    Environment.now = { Date() }

    Environment.fetchCurrentProjectRootURL = { _ in
        URL(fileURLWithPath: "/path/to/project")
    }

    Environment.fetchCurrentFileURL = {
        URL(fileURLWithPath: "/path/to/project/file.swift")
    }

    Environment.createAuthService = {
        fatalError("")
    }

    Environment.createSuggestionService = {
        _ in fatalError("")
    }

    Environment.triggerAction = { _ in }
}

func getService() -> AsyncXPCService {
    AsyncXPCService(connection: {
        class FakeConnection: NSXPCConnection {
            let xpcService = XPCService()
            override func remoteObjectProxyWithErrorHandler(_: @escaping (Error) -> Void) -> Any {
                xpcService
            }
        }
        let connection = FakeConnection(machServiceName: "anything")
        connection.remoteObjectInterface = NSXPCInterface(with: XPCServiceProtocol.self)
        connection.resume()
        return connection
    }())
}

func completion(text: String, range: CursorRange, uuid: String = "") -> CopilotCompletion {
    .init(text: text, position: range.start, uuid: uuid, range: range, displayText: text)
}

class MockSuggestionService: CopilotSuggestionServiceType {
    var completions = [CopilotCompletion]()
    var accepted: String?
    var rejected: [String] = []

    init(completions: [CopilotCompletion]) {
        self.completions = completions
    }

    func getCompletions(
        fileURL _: URL,
        content _: String,
        cursorPosition _: CursorPosition,
        tabSize _: Int,
        indentSize _: Int,
        usesTabsForIndentation _: Bool
    ) async throws -> [CopilotCompletion] {
        completions
    }

    func notifyAccepted(_ completion: CopilotCompletion) async {
        accepted = completion.uuid
    }

    func notifyRejected(_ completions: [CopilotCompletion]) async {
        rejected = completions.map(\.uuid)
    }
}
