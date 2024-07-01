import Client
import Foundation
import SuggestionBasic
import XcodeKit

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

