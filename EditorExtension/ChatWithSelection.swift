import Client
import SuggestionModel
import Foundation
import XcodeKit

class ChatWithSelectionCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Chat with Selection" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
        Task {
            let service = try getService()
            _ = try await service.chatWithSelection(editorContent: .init(invocation))
        }
    }
}
