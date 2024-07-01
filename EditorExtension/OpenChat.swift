import Client
import SuggestionBasic
import Foundation
import XcodeKit

class OpenChatCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Open Chat" }

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
