import Client
import Foundation
import SuggestionBasic
import XcodeKit
import XPCShared

class PreviousSuggestionCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Previous Suggestion" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
        Task {
            let service = try getService()
            _ = try await service.getPreviousSuggestedCode(editorContent: .init(invocation))
        }
    }
}

class PreviousSuggestionGroupCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Previous Suggestion Group" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
        Task {
            let service = try getService()
            _ = try await service
                .send(requestBody: ExtensionServiceRequests.PreviousSuggestionGroup())
        }
    }
}

