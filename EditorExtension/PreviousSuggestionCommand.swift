import Client
import CopilotModel
import Foundation
import XcodeKit

class PreviousSuggestionCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Previous Suggestion" }
    
    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                let service = try getService()
                invocation.accept(try await service.getPreviousSuggestedCode(
                    editorContent: .init(invocation)
                ))
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
}
