import Client
import CopilotModel
import Foundation
import XcodeKit
import XPCShared

class AcceptSuggestionCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Accept Suggestion" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                let service = try getService()
                if let content = try await service.getSuggestionAcceptedCode(
                    editorContent: .init(invocation)
                ) {
                    invocation.accept(content)
                }
                completionHandler(nil)
            } catch is CancellationError {
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
}
