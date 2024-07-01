import Client
import Foundation
import SuggestionBasic
import XcodeKit

class RejectSuggestionCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Reject Suggestion" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
        Task {
            let service = try getService()
            _ = try await service.getSuggestionRejectedCode(editorContent: .init(invocation))
        }
    }
}

