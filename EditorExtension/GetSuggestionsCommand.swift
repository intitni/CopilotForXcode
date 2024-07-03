import Client
import Foundation
import SuggestionBasic
import XcodeKit

class GetSuggestionsCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Get Suggestions" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
        Task {
            let service = try getService()
            _ = try await service.getSuggestedCode(editorContent: .init(invocation))
        }
    }
}

