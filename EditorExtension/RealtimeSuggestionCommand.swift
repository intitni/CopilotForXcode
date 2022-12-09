import Client
import CopilotModel
import Foundation
import XcodeKit

class RealtimeSuggestionsCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Realtime Suggestions" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                let service = try getService()
                invocation.accept(try await service.getRealtimeSuggestedCode(
                    editorContent: .init(invocation)
                ))
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
}
