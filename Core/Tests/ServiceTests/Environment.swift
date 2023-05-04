import AppKit
import Client
import CopilotModel
import GitHubCopilotService
import Environment
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

func completion(text: String, range: CursorRange, uuid: String = "") -> CopilotCompletion {
    .init(text: text, position: range.start, uuid: uuid, range: range, displayText: text)
}

class MockSuggestionService: CopilotSuggestionServiceType {
    func notifyOpenTextDocument(fileURL: URL, content: String) async throws {
        fatalError()
    }
    
    func notifyChangeTextDocument(fileURL: URL, content: String) async throws {
        fatalError()
    }
    
    func notifyCloseTextDocument(fileURL: URL) async throws {
        fatalError()
    }
    
    func notifySaveTextDocument(fileURL: URL) async throws {
        fatalError()
    }
    
    var completions = [CopilotCompletion]()
    var accepted: String?
    var rejected: [String] = []

    init(completions: [CopilotCompletion]) {
        self.completions = completions
    }

    func getCompletions(
        fileURL: URL,
        content: String,
        cursorPosition: CopilotModel.CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        ignoreSpaceOnlySuggestions: Bool
    ) async throws -> [CopilotModel.CopilotCompletion] {
        completions
    }

    func notifyAccepted(_ completion: CopilotCompletion) async {
        accepted = completion.uuid
    }

    func notifyRejected(_ completions: [CopilotCompletion]) async {
        rejected = completions.map(\.uuid)
    }
}
