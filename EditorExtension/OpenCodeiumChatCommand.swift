import Client
import SuggestionModel
import Foundation
import XcodeKit

class OpenCodeiumChatCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Open Codeium Chat" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
        Task {
            let service = try getService()
            _ = try await service.openChat(editorContent: .init(invocation))
        }
    }
}
