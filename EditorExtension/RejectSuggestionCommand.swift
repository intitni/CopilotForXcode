import Client
import CopilotModel
import Foundation
import XcodeKit

class RejectSuggestionCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Reject Suggestion" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                let service = try getService()
                if let content = try await service.getSuggestionRejectedCode(
                    editorContent: .init(invocation)
                ) {
                    invocation.accept(content)
                }
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
}
