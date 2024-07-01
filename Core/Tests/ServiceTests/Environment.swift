import AppKit
import Client
import Foundation
import GitHubCopilotService
import SuggestionBasic
import Workspace
import XCTest
import XPCShared

@testable import Service

func completion(text: String, range: CursorRange, uuid: String = "") -> CodeSuggestion {
    .init(id: uuid, text: text, position: range.start, range: range)
}

class MockSuggestionService: GitHubCopilotSuggestionServiceType {
    func notifyChangeTextDocument(fileURL: URL, content: String, version: Int) async throws {
        fatalError()
    }

    func terminate() async {
        fatalError()
    }

    func cancelRequest() async {
        fatalError()
    }

    func notifyOpenTextDocument(fileURL: URL, content: String) async throws {
        fatalError()
    }

    func notifyCloseTextDocument(fileURL: URL) async throws {
        fatalError()
    }

    func notifySaveTextDocument(fileURL: URL) async throws {
        fatalError()
    }

    var completions = [CodeSuggestion]()
    var accepted: String?
    var rejected: [String] = []

    init(completions: [CodeSuggestion]) {
        self.completions = completions
    }

    func getCompletions(
        fileURL: URL,
        content: String,
        originalContent: String,
        cursorPosition: SuggestionBasic.CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool
    ) async throws -> [SuggestionBasic.CodeSuggestion] {
        completions
    }

    func notifyAccepted(_ completion: CodeSuggestion) async {
        accepted = completion.id
    }

    func notifyRejected(_ completions: [CodeSuggestion]) async {
        rejected = completions.map(\.id)
    }
}

