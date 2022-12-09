import Client
import CopilotModel
import Foundation
import XcodeKit

class NextSuggestionCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Next Suggestion" }
    
    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                let service = try getService()
                invocation.accept(try await service.getNextSuggestedCode(
                    editorContent: .init(invocation)
                ))
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
}
