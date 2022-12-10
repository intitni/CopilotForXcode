import Client
import CopilotModel
import Foundation
import XcodeKit

class GetSuggestionsCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Get Suggestions" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                let service = try getService()
                if let content = try await service.getSuggestedCode(
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
