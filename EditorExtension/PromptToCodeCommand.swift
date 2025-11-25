import Client
import SuggestionBasic
import Foundation
import XcodeKit

class PromptToCodeCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Write or Edit Code" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
        Task {
            let service = try getService()
            _ = try await service.promptToCode(editorContent: .init(invocation))
        }
    }
}
