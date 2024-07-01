import Client
import Foundation
import SuggestionBasic
import XcodeKit

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

