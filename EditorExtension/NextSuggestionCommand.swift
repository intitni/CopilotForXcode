import Client
import Foundation
import SuggestionBasic
import XcodeKit
import XPCShared

class NextSuggestionCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Next Suggestion" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
        Task {
            let service = try getService()
            _ = try await service.getNextSuggestedCode(editorContent: .init(invocation))
        }
    }
}

class NextSuggestionGroupCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Next Suggestion Group" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
        Task {
            let service = try getService()
            _ = try await service
                .send(requestBody: ExtensionServiceRequests.NextSuggestionGroup())
        }
    }
}

