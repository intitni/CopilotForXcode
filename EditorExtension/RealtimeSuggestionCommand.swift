import Client
import SuggestionBasic
import Foundation
import XcodeKit

class RealtimeSuggestionsCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Prepare for Real-time Suggestions" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
        Task {
            let service = try getService()
            _ = try await service.getRealtimeSuggestedCode(editorContent: .init(invocation))
        }
    }
}
